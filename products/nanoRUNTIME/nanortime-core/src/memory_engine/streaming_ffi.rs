//! nanortime_streaming.rs — FFI bridge for CacheAwareLoader → llama.cpp
//!
//! Compiled as a static library (staticlib) that llama.cpp links against.
//! Exposes C-compatible functions for layer-level memory streaming.
//!
//! Build: cargo build --lib --target aarch64-linux-android --release
//! Output: target/aarch64-linux-android/release/libnanortime_streaming.a

use std::ffi::c_void;
use std::fs::File;
use std::panic::catch_unwind;
use std::sync::Mutex;

use crate::memory_engine::cache_aware_loader::{
    can_stream_model, CacheAwareLoader, StreamingConfig,
};
use crate::memory_engine::gguf_layout::NanoModelIndex;

static LOADER: Mutex<Option<CacheAwareLoader>> = Mutex::new(None);
static LAYER_COUNT: Mutex<usize> = Mutex::new(0);

/// Helper: locks a Mutex and returns the guard, logging & returning
/// a safe fallback on poison instead of panicking (which is UB across FFI).
fn lock_or_null<T>(mutex: &Mutex<T>) -> Option<std::sync::MutexGuard<'_, T>> {
    match mutex.lock() {
        Ok(g) => Some(g),
        Err(poisoned) => {
            tracing::error!("FFI Mutex poisoned — recovering inner data");
            // Poisoned mutex still contains valid data; recover it.
            Some(poisoned.into_inner())
        }
    }
}

/// Initialize the streaming loader. Called once before inference.
///
/// # Safety
/// Call exactly once at startup. Not thread-safe by design — must be called
/// from the main thread before any inference threads spawn.
#[no_mangle]
pub unsafe extern "C" fn nanortime_streaming_init(
    gguf_path: *const std::os::raw::c_char,
    window_layers: std::os::raw::c_int,
) -> std::os::raw::c_int {
    std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| {
        let path_str = unsafe {
            if gguf_path.is_null() {
                return -1;
            }
            std::ffi::CStr::from_ptr(gguf_path)
                .to_string_lossy()
                .into_owned()
        };

        let file = match File::open(&path_str) {
            Ok(f) => f,
            Err(_) => return -2,
        };

        let layout = match NanoModelIndex::analyze(std::path::Path::new(&path_str), 32) {
            Ok(l) => l,
            Err(_) => return -3,
        };

        let mut layer_ranges: Vec<_> = layout.layers.iter().collect();
        layer_ranges.sort_by_key(|(idx, _)| *idx);
        let ranges: Vec<_> = layer_ranges.iter().map(|(_, r)| r.byte_range.clone()).collect();

        if ranges.is_empty() {
            return -4;
        }

        let config = StreamingConfig {
            window_layers: window_layers as usize,
            use_page_cache_hints: true,
            populate_active: false,
            storage_alignment: 262144,
        };

        let loader = match CacheAwareLoader::new(&file, &ranges, config) {
            Ok(l) => l,
            Err(_) => return -5,
        };

        let total = loader.total_layers();
        if let Some(mut lc) = lock_or_null(&LAYER_COUNT) {
            *lc = total;
        }
        if let Some(mut ld) = lock_or_null(&LOADER) {
            *ld = Some(loader);
        }

        total as std::os::raw::c_int
    }))
    .unwrap_or_else(|_| {
        tracing::error!("panic in nanortime_streaming_init — caught and suppressed");
        -1
    })
}

/// Load layer `layer_idx` into the sliding window.
/// Returns a pointer to the layer's weights, or null if out of range.
///
/// # Safety
/// `layer_idx` must be < total_layers. The returned pointer is valid until
/// the next call to `nanortime_streaming_load()` or `nanortime_streaming_unload()`.
#[no_mangle]
pub extern "C" fn nanortime_streaming_load(layer_idx: std::os::raw::c_int) -> *mut c_void {
    catch_unwind(std::panic::AssertUnwindSafe(|| {
        let mut guard = lock_or_null(&LOADER);
        let loader = match guard.as_mut().and_then(|g| g.as_mut()) {
            Some(l) => l,
            None => return std::ptr::null_mut(),
        };

        match loader.load_layer(layer_idx as usize) {
            Ok(_) => unsafe { loader.get_layer_ptr(layer_idx as usize) }
                .map(|p| p as *mut c_void)
                .unwrap_or(std::ptr::null_mut()),
            Err(_) => std::ptr::null_mut(),
        }
    }))
    .unwrap_or(std::ptr::null_mut())
}

/// Release pages for all layers in the current window.
/// Forces MADV_DONTNEED + MADV_PAGEOUT before munmap.
///
/// # Safety
/// Must be called with the same `layer_idx` that was passed to `load()`.
#[no_mangle]
pub extern "C" fn nanortime_streaming_release(_layer_idx: std::os::raw::c_int) {
    let _ = catch_unwind(std::panic::AssertUnwindSafe(|| {
        let mut guard = lock_or_null(&LOADER);
        if let Some(loader) = guard.as_mut().and_then(|g| g.as_mut()) {
            let _ = loader.unmap_current();
        }
    }));
}

/// Get current VMA size in bytes.
#[no_mangle]
pub extern "C" fn nanortime_streaming_vma_bytes() -> std::os::raw::c_ulong {
    catch_unwind(std::panic::AssertUnwindSafe(|| {
        let guard = lock_or_null(&LOADER);
        match guard.as_ref().and_then(|opt| opt.as_ref()) {
            Some(loader) => loader.vma_bytes() as std::os::raw::c_ulong,
            None => 0,
        }
    }))
    .unwrap_or(0)
}

/// Check if the device can safely stream this model.
#[no_mangle]
pub extern "C" fn nanortime_streaming_can_run(
    total_layers: std::os::raw::c_int,
    window_layers: std::os::raw::c_int,
    ram_total_mb: std::os::raw::c_ulong,
) -> std::os::raw::c_int {
    catch_unwind(std::panic::AssertUnwindSafe(|| {
        let bytes_per_layer = 140 * 1024 * 1024;
        if can_stream_model(
            total_layers as usize,
            window_layers as usize,
            bytes_per_layer,
            ram_total_mb as u64,
        ) {
            1
        } else {
            0
        }
    }))
    .unwrap_or(0)
}

/// Get the total number of layers.
#[no_mangle]
pub extern "C" fn nanortime_streaming_layer_count() -> std::os::raw::c_int {
    catch_unwind(std::panic::AssertUnwindSafe(|| {
        lock_or_null(&LAYER_COUNT).map(|g| *g).unwrap_or(0) as std::os::raw::c_int
    }))
    .unwrap_or(0)
}
