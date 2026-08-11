//! Weight Cache Manager — Surgical page eviction for KV cache tensors.
//!
//! Marks cold pages for eviction (MADV_COLD / MADV_PAGEOUT) before munmap
//! to ensure the kernel reclaims physical pages immediately on constrained
//! devices (<4 GB RAM). This is the difference between survival and OOM
//! Killer termination.

/// Configuration for weight cache eviction.
#[derive(Debug, Clone)]
pub struct WeightCacheConfig {
    /// Number of cold pages to mark before munmap.
    pub cold_page_threshold: usize,
    /// Whether to use MADV_PAGEOUT (Linux 5.4+) aggressively.
    pub use_pageout: bool,
}

impl Default for WeightCacheConfig {
    fn default() -> Self {
        Self {
            cold_page_threshold: 0, // mark all pages in range
            use_pageout: true,
        }
    }
}

/// Manages surgical eviction of weight cache pages.
pub struct WeightCacheManager {
    _config: WeightCacheConfig,
}

impl WeightCacheManager {
    pub fn new(config: WeightCacheConfig) -> Self {
        Self { _config: config }
    }

    /// Mark KV cache pages as cold, hinting the kernel to reclaim them
    /// under memory pressure.
    ///
    /// # Safety
    /// `ptr` must point to a valid, page-aligned memory region of at
    /// least `size` bytes that was previously mapped.
    pub unsafe fn mark_kv_cold(&self, ptr: *mut u8, size: usize) -> std::io::Result<()> {
        if ptr.is_null() || size == 0 {
            return Ok(());
        }
        #[cfg(any(target_os = "linux", target_os = "android"))]
        {
            // Linux kernel 5.4+ only. Silently fall through on older kernels.
            let ret = libc::madvise(ptr as *mut libc::c_void, size, libc::MADV_COLD);
            if ret != 0 {
                let err = std::io::Error::last_os_error();
                // EINVAL = kernel too old, not an error worth propagating.
                if err.raw_os_error() != Some(libc::EINVAL) {
                    return Err(err);
                }
            }
        }
        #[cfg(not(any(target_os = "linux", target_os = "android")))]
        {
            let _ = (ptr, size);
        }
        Ok(())
    }

    /// Aggressively page out KV cache pages before munmap.
    ///
    /// # Safety
    /// `ptr` must point to a valid, page-aligned memory region of at
    /// least `size` bytes that was previously mapped.
    pub unsafe fn pageout_kv(&self, ptr: *mut u8, size: usize) -> std::io::Result<()> {
        if ptr.is_null() || size == 0 {
            return Ok(());
        }
        #[cfg(any(target_os = "linux", target_os = "android"))]
        {
            let ret = libc::madvise(ptr as *mut libc::c_void, size, libc::MADV_PAGEOUT);
            if ret != 0 {
                let err = std::io::Error::last_os_error();
                if err.raw_os_error() != Some(libc::EINVAL) {
                    return Err(err);
                }
            }
        }
        #[cfg(not(any(target_os = "linux", target_os = "android")))]
        {
            let _ = (ptr, size);
        }
        Ok(())
    }
}
