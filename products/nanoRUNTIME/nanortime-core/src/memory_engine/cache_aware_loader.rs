//! Cache-Aware Model Loader — VMA-safe streaming layer loader.
//! Linux/Android only. Non-Linux gets stubs.

use crate::memory_engine::types::ByteRange;
use std::io;

// ── Types always available ───────────────────────────────────────────

#[derive(Debug, Clone)]
pub struct StreamingConfig {
    pub window_layers: usize,
    pub use_page_cache_hints: bool,
    pub populate_active: bool,
    pub storage_alignment: usize,
}
impl Default for StreamingConfig {
    fn default() -> Self {
        Self {
            window_layers: 3,
            use_page_cache_hints: true,
            populate_active: false,
            storage_alignment: 262144,
        }
    }
}

#[derive(Debug)]
pub struct LoadResult {
    pub bytes_loaded: usize,
    pub vma_bytes: usize,
    pub window_rolls: usize,
}

pub fn estimate_vma_bytes(
    total_layers: usize,
    window_layers: usize,
    bytes_per_layer: usize,
) -> usize {
    (window_layers.min(total_layers) * bytes_per_layer) + 250 * 1024 * 1024
}

pub fn can_stream_model(
    total_layers: usize,
    window_layers: usize,
    bytes_per_layer: usize,
    ram_total_mb: u64,
) -> bool {
    let vma = estimate_vma_bytes(total_layers, window_layers, bytes_per_layer);
    vma < (ram_total_mb as f64 * 0.75 * 1024.0 * 1024.0) as usize
}

// ── Linux/Android CacheAwareLoader ────────────────────────────────────

#[cfg(any(target_os = "linux", target_os = "android"))]
pub struct CacheAwareLoader {
    fd: std::os::unix::io::RawFd,
    layers: Vec<ByteRange>,
    config: StreamingConfig,
    window: WindowState,
    mmap_ptr: std::sync::atomic::AtomicUsize,
    mmap_size: std::sync::atomic::AtomicUsize,
    /// File offset that the mmap is aligned to. Layer offsets are relative
    /// to this, NOT to the window start, because mmap requires page alignment.
    mmap_base_offset: usize,
    _file_size: usize,
}

#[cfg(any(target_os = "linux", target_os = "android"))]
struct WindowState {
    start_layer: usize,
    end_layer: usize,
    total_layers: usize,
}

#[cfg(any(target_os = "linux", target_os = "android"))]
impl CacheAwareLoader {
    /// Creates a new CacheAwareLoader.
    ///
    /// The provided `file` is only borrowed to obtain the fd and file size.
    /// The fd is duplicated internally via `libc::dup()`, so the caller may
    /// drop `file` immediately after this call returns without invalidating
    /// the loader. The duplicated fd is closed in `Drop`.
    pub fn new(
        file: &std::fs::File,
        layer_ranges: &[ByteRange],
        config: StreamingConfig,
    ) -> io::Result<Self> {
        use std::os::unix::io::AsRawFd;
        let raw_fd = file.as_raw_fd();
        // Duplicate the fd so the loader owns an independent file descriptor.
        // The caller may drop `file` immediately after construction — the dup'd
        // fd remains valid for mmap calls throughout the loader's lifetime.
        let dup_fd = unsafe { libc::dup(raw_fd) };
        if dup_fd < 0 {
            return Err(io::Error::last_os_error());
        }
        Ok(Self {
            fd: dup_fd,
            layers: layer_ranges.to_vec(),
            config,
            window: WindowState {
                start_layer: 0,
                end_layer: 0,
                total_layers: layer_ranges.len(),
            },
            mmap_ptr: std::sync::atomic::AtomicUsize::new(0),
            mmap_size: std::sync::atomic::AtomicUsize::new(0),
            mmap_base_offset: 0,
            _file_size: file.metadata()?.len() as usize,
        })
    }

    pub fn load_layer(&mut self, target_layer: usize) -> io::Result<LoadResult> {
        use std::sync::atomic::Ordering;
        if target_layer >= self.window.total_layers {
            return Err(io::Error::new(
                io::ErrorKind::InvalidInput,
                "layer out of range",
            ));
        }
        if target_layer >= self.window.start_layer && target_layer < self.window.end_layer {
            return Ok(LoadResult {
                bytes_loaded: 0,
                vma_bytes: self.mmap_size.load(Ordering::Acquire),
                window_rolls: 0,
            });
        }
        self.unmap_current()?;
        let half = self.config.window_layers / 2;
        let new_start = target_layer.saturating_sub(half);
        let new_end = (new_start + self.config.window_layers).min(self.window.total_layers);
        let new_start = new_end.saturating_sub(self.config.window_layers);
        let byte_start = self.layers[new_start].start;
        let byte_end = self.layers[new_end - 1].end;
        let window_size = byte_end - byte_start;

        // Use dynamic page size detection instead of hardcoded 4096
        let page_size = self.detect_page_size();
        let aligned_start = (byte_start / page_size) * page_size;
        let aligned_size =
            (window_size + (byte_start - aligned_start)).div_ceil(page_size) * page_size;
        let ptr = unsafe {
            libc::mmap(
                std::ptr::null_mut(),
                aligned_size,
                libc::PROT_READ,
                libc::MAP_PRIVATE,
                self.fd,
                aligned_start as libc::off_t,
            )
        };
        if ptr == libc::MAP_FAILED {
            return Err(io::Error::last_os_error());
        }
        self.mmap_base_offset = aligned_start;
        if self.config.use_page_cache_hints {
            // MADV_SEQUENTIAL is advisory — failure degrades to default
            // kernel behavior and is not a hard error. Log for diagnostics.
            let ret = unsafe { libc::madvise(ptr, aligned_size, libc::MADV_SEQUENTIAL) };
            if ret != 0 {
                tracing::debug!(
                    "madvise(MADV_SEQUENTIAL) failed: {:?}",
                    std::io::Error::last_os_error()
                );
            }
        }
        self.mmap_ptr.store(ptr as usize, Ordering::Release);
        self.mmap_size.store(aligned_size, Ordering::Release);
        self.window.start_layer = new_start;
        self.window.end_layer = new_end;
        Ok(LoadResult {
            bytes_loaded: aligned_size,
            vma_bytes: aligned_size,
            window_rolls: 1,
        })
    }

    /// Return pointer to layer data inside current mmap window.
    ///
    /// # Safety
    ///
    /// Caller must ensure the returned pointer is only dereferenced while the
    /// layer remains loaded in the current cache window and the loader is alive.
    /// Any call that remaps/unmaps the window invalidates previously returned
    /// pointers.
    pub unsafe fn get_layer_ptr(&self, layer_idx: usize) -> io::Result<*const u8> {
        use std::sync::atomic::Ordering;
        if layer_idx < self.window.start_layer || layer_idx >= self.window.end_layer {
            return Err(io::Error::new(
                io::ErrorKind::NotFound,
                "layer not in window",
            ));
        }
        let base = self.mmap_ptr.load(Ordering::Acquire) as *const u8;
        // Layer offsets are absolute file offsets; mmap is page-aligned.
        // Pointer = base + (layer_offset - mmap_base_offset).
        let offset = self.layers[layer_idx]
            .start
            .saturating_sub(self.mmap_base_offset);
        Ok(base.add(offset))
    }

    pub fn vma_bytes(&self) -> usize {
        self.mmap_size.load(std::sync::atomic::Ordering::Acquire)
    }
    pub fn total_layers(&self) -> usize {
        self.window.total_layers
    }
    pub fn current_window(&self) -> (usize, usize) {
        (self.window.start_layer, self.window.end_layer)
    }
    pub fn is_loaded(&self, l: usize) -> bool {
        l >= self.window.start_layer && l < self.window.end_layer
    }

    /// Detect system page size for alignment
    fn detect_page_size(&self) -> usize {
        #[cfg(unix)]
        {
            let page_size = unsafe { libc::sysconf(libc::_SC_PAGESIZE) as usize };
            if page_size > 0 {
                return page_size;
            }
        }

        #[cfg(windows)]
        {
            use windows_sys::Win32::System::SystemInformation::GetSystemInfo;
            let mut sys_info = std::mem::zeroed();
            unsafe { GetSystemInfo(&mut sys_info) };
            let page_size = sys_info.dwPageSize as usize;
            if page_size > 0 {
                return page_size;
            }
        }

        // Fallback to 4KB
        4096
    }

    pub fn unmap_current(&mut self) -> io::Result<()> {
        use std::sync::atomic::Ordering;
        let ptr = self.mmap_ptr.load(Ordering::Acquire);
        let size = self.mmap_size.load(Ordering::Acquire);
        if ptr != 0 && size > 0 {
            // ── V2: WeightCacheAware — surgical page eviction ──────
            // Issue MADV_DONTNEED (or MADV_PAGEOUT on 5.4+) before munmap
            // to ensure the kernel reclaims physical pages immediately.
            // On constrained devices (<4 GB), this is the difference between
            // survival and OOM Killer termination.
            let wc = crate::memory_engine::weight_cache_aware::WeightCacheManager::new(
                crate::memory_engine::weight_cache_aware::WeightCacheConfig::default(),
            );
            let _ = unsafe { wc.mark_kv_cold(ptr as *mut u8, size) };
            let _ = unsafe { wc.pageout_kv(ptr as *mut u8, size) };

            if unsafe { libc::munmap(ptr as *mut libc::c_void, size) != 0 } {
                return Err(io::Error::last_os_error());
            }
        }
        self.mmap_ptr.store(0, Ordering::Release);
        self.mmap_size.store(0, Ordering::Release);
        Ok(())
    }
}

#[cfg(any(target_os = "linux", target_os = "android"))]
impl Drop for CacheAwareLoader {
    fn drop(&mut self) {
        let _ = self.unmap_current();
        // Close the duplicated fd we created in new().
        // Safe even if close fails — the fd is leaked but the OS
        // will reclaim it on process exit.
        if self.fd >= 0 {
            unsafe {
                libc::close(self.fd);
            }
        }
    }
}

// ── Non-Linux stub ──────────────────────────────────────────────────

#[cfg(not(any(target_os = "linux", target_os = "android")))]
pub struct CacheAwareLoader;

#[cfg(not(any(target_os = "linux", target_os = "android")))]
impl CacheAwareLoader {
    pub fn new(
        _file: &std::fs::File,
        _layer_ranges: &[ByteRange],
        _config: StreamingConfig,
    ) -> io::Result<Self> {
        Err(io::Error::new(
            io::ErrorKind::Unsupported,
            "CacheAwareLoader requires Linux/Android",
        ))
    }
    pub fn load_layer(&mut self, _target: usize) -> io::Result<LoadResult> {
        Ok(LoadResult {
            bytes_loaded: 0,
            vma_bytes: 0,
            window_rolls: 0,
        })
    }
    /// Return pointer to requested layer data.
    ///
    /// # Safety
    ///
    /// Caller must ensure returned pointer is not dereferenced after current
    /// cache window is unmapped or after loader is dropped. This unsupported
    /// platform implementation always returns null.
    pub unsafe fn get_layer_ptr(&self, _layer: usize) -> io::Result<*const u8> {
        Ok(std::ptr::null())
    }
    pub fn vma_bytes(&self) -> usize {
        0
    }
    pub fn total_layers(&self) -> usize {
        0
    }
    pub fn current_window(&self) -> (usize, usize) {
        (0, 0)
    }
    pub fn is_loaded(&self, _l: usize) -> bool {
        false
    }
    pub fn unmap_current(&mut self) -> io::Result<()> {
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_estimate_vma_7b() {
        let vma = estimate_vma_bytes(32, 3, 140 * 1024 * 1024);
        assert!(vma < 800 * 1024 * 1024);
    }
    #[test]
    fn test_can_stream_samsung() {
        assert!(can_stream_model(32, 3, 140 * 1024 * 1024, 3814));
    }
    #[test]
    fn test_can_stream_rejects_small() {
        assert!(!can_stream_model(32, 3, 140 * 1024 * 1024, 512));
    }
}
