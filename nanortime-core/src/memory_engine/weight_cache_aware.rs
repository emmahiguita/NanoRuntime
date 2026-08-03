//! Weight Cache Manager — Keep model weights in kernel Page Cache, not process RSS.
//!
//! ## The Problem
//!
//! When Linux reads a file via mmap, pages land in the **Page Cache** (kernel memory).
//! These pages DON'T count against the process RSS — only against MemAvailable.
//! But without proper hints, the kernel may evict weight pages under pressure,
//! causing page faults that stall inference (access drops from ns to ms).
//!
//! ## The Solution: Page Cache Orchestration
//!
//! 1. **Warm**: On model load, issue MADV_SEQUENTIAL + MADV_WILLNEED so the kernel
//!    eagerly populates the Page Cache with weights.
//! 2. **Keep**: NEVER issue MADV_DONTNEED on weight pages. Let the kernel decide when
//!    to evict — it has better heuristics than we do.
//! 3. **Cold**: For KV cache tokens (NOT weights), use MADV_COLD (kernel 5.14+)
//!    or MADV_PAGEOUT to push cold tokens to swap/ZRAM, keeping hot tokens fast.
//!
//! ## Integration
//!
//! This module is a **companion** to StorageManager, not a replacement.
//! StorageManager handles mmap lifecycle; WeightCacheManager adds precise hints.
//!
//! Linux/Android only. Non-Linux gets no-op stubs.

use std::io;

/// Strategy for managing weight residency.
#[derive(Debug, Clone, Copy, PartialEq)]
pub enum CacheStrategy {
    /// Keep weights in Page Cache aggressively (default for devices >4 GB).
    Aggressive,
    /// Balanced: warm on load, let kernel manage (4-6 GB).
    Balanced,
    /// Conservative: warm only active layer, let kernel evict freely (<4 GB).
    Conservative,
}

/// Configuration for weight cache management.
#[derive(Debug, Clone)]
pub struct WeightCacheConfig {
    pub strategy: CacheStrategy,
    /// Whether to use MAP_POPULATE during initial mmap (pre-faults pages).
    pub populate_on_load: bool,
    /// Use MADV_COLD (Linux 5.14+) for cold KV tokens.
    pub use_madv_cold: bool,
}

impl Default for WeightCacheConfig {
    fn default() -> Self {
        Self { strategy: CacheStrategy::Balanced, populate_on_load: false, use_madv_cold: false }
    }
}

/// Select best strategy based on available RAM.
pub fn select_strategy(ram_total_mb: u64) -> CacheStrategy {
    if ram_total_mb > 6000 {
        CacheStrategy::Aggressive
    } else if ram_total_mb > 4000 {
        CacheStrategy::Balanced
    } else {
        CacheStrategy::Conservative
    }
}

// ── Linux/Android implementation ─────────────────────────────────────

#[cfg(any(target_os = "linux", target_os = "android"))]
pub struct WeightCacheManager {
    config: WeightCacheConfig,
    total_warmed_bytes: usize,
}

#[cfg(any(target_os = "linux", target_os = "android"))]
impl WeightCacheManager {
    /// Create a new weight cache manager.
    pub fn new(config: WeightCacheConfig) -> Self {
        Self { config, total_warmed_bytes: 0 }
    }

    /// Warm weights into Page Cache.
    ///
    /// Issues MADV_SEQUENTIAL | MADV_WILLNEED to tell the kernel:
    /// "I'll access this sequentially, please prefetch it."
    /// The pages land in Page Cache, NOT the process RSS.
    ///
    /// # Safety
    /// `ptr` must be a valid mmap'd region of `size` bytes.
    pub unsafe fn warm_weights(&mut self, ptr: *mut u8, size: usize) -> io::Result<()> {
        if size == 0 { return Ok(()); }

        // Page-align
        let page_size = 4096;
        let aligned_ptr = ((ptr as usize / page_size) * page_size) as *mut libc::c_void;
        let aligned_size = ((size + (ptr as usize % page_size) + page_size - 1) / page_size) * page_size;

        let advice = match self.config.strategy {
            CacheStrategy::Aggressive => libc::MADV_SEQUENTIAL | libc::MADV_WILLNEED,
            CacheStrategy::Balanced => libc::MADV_SEQUENTIAL,
            CacheStrategy::Conservative => libc::MADV_WILLNEED,
        };

        let rc = libc::madvise(aligned_ptr, aligned_size, advice);
        if rc != 0 {
            let err = io::Error::last_os_error();
            // EINVAL = kernel doesn't support combined advice flags. Fall back.
            if err.raw_os_error() == Some(libc::EINVAL) {
                libc::madvise(aligned_ptr, aligned_size, libc::MADV_WILLNEED);
            } else {
                return Err(err);
            }
        }

        self.total_warmed_bytes += aligned_size;
        Ok(())
    }

    /// Mark KV-cache tokens as cold.
    ///
    /// MADV_COLD (Linux 5.14+) marks pages as inactive — the kernel will
    /// reclaim them before hot pages. Falls back to no-op on older kernels.
    ///
    /// # Safety
    /// `ptr` must be a valid mmap'd region of `size` bytes.
    pub unsafe fn mark_kv_cold(&self, ptr: *mut u8, size: usize) -> io::Result<()> {
        if size == 0 || !self.config.use_madv_cold { return Ok(()); }

        let page_size = 4096;
        let aligned_ptr = ((ptr as usize / page_size) * page_size) as *mut libc::c_void;
        let aligned_size = ((size + (ptr as usize % page_size) + page_size - 1) / page_size) * page_size;

        // Try MADV_COLD (kernel 5.14+)
        let rc = libc::madvise(aligned_ptr, aligned_size, libc::MADV_COLD);
        if rc != 0 {
            let err = io::Error::last_os_error();
            if err.raw_os_error() == Some(libc::EINVAL) {
                // Kernel too old. MADV_COLD not supported. Acceptable.
                return Ok(());
            }
            return Err(err);
        }
        Ok(())
    }

    /// Push cold KV pages to swap/ZRAM.
    ///
    /// Stronger than MADV_COLD: forces immediate reclaim. Use only when
    /// MemAvailable < 200 MB and we need pages freed NOW.
    ///
    /// # Safety
    /// `ptr` must be a valid mmap'd region.
    pub unsafe fn pageout_kv(&self, ptr: *mut u8, size: usize) -> io::Result<()> {
        if size == 0 { return Ok(()); }

        let page_size = 4096;
        let aligned_ptr = ((ptr as usize / page_size) * page_size) as *mut libc::c_void;
        let aligned_size = ((size + (ptr as usize % page_size) + page_size - 1) / page_size) * page_size;

        let rc = libc::madvise(aligned_ptr, aligned_size, libc::MADV_PAGEOUT);
        if rc != 0 {
            let err = io::Error::last_os_error();
            if err.raw_os_error() == Some(libc::EINVAL) { return Ok(()); } // Kernel too old
            return Err(err);
        }
        Ok(())
    }

    /// Keep pages resident. Opposite of DONTNEED — tells kernel these matter.
    ///
    /// # Safety
    /// `ptr` must be a valid mmap'd region.
    pub unsafe fn keep_resident(&self, ptr: *mut u8, size: usize) -> io::Result<()> {
        if size == 0 { return Ok(()); }
        let page_size = 4096;
        let aligned_ptr = ((ptr as usize / page_size) * page_size) as *mut libc::c_void;
        let aligned_size = ((size + (ptr as usize % page_size) + page_size - 1) / page_size) * page_size;
        let rc = libc::madvise(aligned_ptr, aligned_size, libc::MADV_WILLNEED);
        if rc != 0 { return Err(io::Error::last_os_error()); }
        Ok(())
    }

    /// Total bytes warmed into Page Cache so far.
    pub fn total_warmed(&self) -> usize { self.total_warmed_bytes }

    /// Current configuration.
    pub fn config(&self) -> &WeightCacheConfig { &self.config }
}

// ── Non-Linux stub ──────────────────────────────────────────────────

#[cfg(not(any(target_os = "linux", target_os = "android")))]
pub struct WeightCacheManager { config: WeightCacheConfig }

#[cfg(not(any(target_os = "linux", target_os = "android")))]
impl WeightCacheManager {
    pub fn new(config: WeightCacheConfig) -> Self { Self { config } }
    pub unsafe fn warm_weights(&mut self, _ptr: *mut u8, _size: usize) -> io::Result<()> { Ok(()) }
    pub unsafe fn mark_kv_cold(&self, _ptr: *mut u8, _size: usize) -> io::Result<()> { Ok(()) }
    pub unsafe fn pageout_kv(&self, _ptr: *mut u8, _size: usize) -> io::Result<()> { Ok(()) }
    pub unsafe fn keep_resident(&self, _ptr: *mut u8, _size: usize) -> io::Result<()> { Ok(()) }
    pub fn total_warmed(&self) -> usize { 0 }
    pub fn config(&self) -> &WeightCacheConfig { &self.config }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_select_strategy_low_ram() {
        assert_eq!(select_strategy(3724), CacheStrategy::Conservative);
    }

    #[test]
    fn test_select_strategy_mid_ram() {
        assert_eq!(select_strategy(5000), CacheStrategy::Balanced);
    }

    #[test]
    fn test_select_strategy_high_ram() {
        assert_eq!(select_strategy(8000), CacheStrategy::Aggressive);
    }

    #[test]
    fn test_default_config() {
        let cfg = WeightCacheConfig::default();
        assert_eq!(cfg.strategy, CacheStrategy::Balanced);
        assert!(!cfg.populate_on_load);
    }
}
