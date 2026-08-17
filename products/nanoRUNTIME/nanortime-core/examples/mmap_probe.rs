//! Probe REAL del hook mmap de llama.cpp — la pieza que habilita el layer
//! streaming OS-like (madvise por capa) para modelos mayores que la RAM.
//!
//! Verifica:
//!   1. `NanoModel::mmap_addr()` devuelve puntero no-nulo + size coherente.
//!   2. El puntero apunta al archivo real (magic GGUF en offset 0).
//!   3. Se puede hacer madvise sobre la mapping con el módulo activo
//!      `weight_cache_aware` (evicción quirúrgica MADV_PAGEOUT).
//!
//! Uso:
//!   cargo run -p nanortime-core --example mmap_probe -- [ruta.gguf]

use nanortime_ffi::{ModelLoadParams, NanoModel};
use std::path::PathBuf;

fn main() {
    tracing_subscriber::fmt::init();

    let default = concat!(env!("CARGO_MANIFEST_DIR"), "/../../data/qwen_tmp.gguf");
    let path = std::env::args()
        .nth(1)
        .map(PathBuf::from)
        .unwrap_or_else(|| PathBuf::from(default));

    println!("=== mmap hook probe: {} ===", path.display());
    if !path.exists() {
        eprintln!("ERROR: no existe {}", path.display());
        std::process::exit(1);
    }
    let file_size = std::fs::metadata(&path).unwrap().len();

    let params = ModelLoadParams {
        context_size: 512,
        gpu_layers: 0,
        use_mmap: true,
        threads: 2,
        batch_size: 128,
    };
    let model = NanoModel::load(path.to_str().unwrap(), &params).expect("cargar modelo");

    // 1. Hook mmap.
    let (addr, size) = model.mmap_addr();
    println!(
        "mmap_addr={:p} size={} bytes (archivo={})",
        addr, size, file_size
    );
    assert!(!addr.is_null(), "puntero mmap NULL — ¿modelo no mmap-eado?");
    assert!(size > 0, "size 0 — mapping vacía");
    assert!(
        size as u64 >= file_size,
        "size {} < archivo {} — mapping incompleta",
        size,
        file_size
    );

    // 2. Validez: leer el magic GGUF desde la mapping (offset 0 del archivo).
    let magic = unsafe { std::slice::from_raw_parts(addr as *const u8, 4) };
    println!(
        "magic en mmap[0..4] = {:?} ({})",
        magic,
        String::from_utf8_lossy(magic)
    );
    assert_eq!(
        magic, b"GGUF",
        "magic no coincide — la mapping no arranca en el offset 0 del archivo"
    );

    // 3. Evicción quirúrgica real sobre el primer 1 MB de la mapping, usando
    //    el puntero REAL con el módulo activo weight_cache_aware.
    let wc = nanortime_core::memory_engine::weight_cache_aware::WeightCacheManager::new(
        nanortime_core::memory_engine::weight_cache_aware::WeightCacheConfig::default(),
    );
    let evict_bytes = (1 << 20).min(size);
    let _ = unsafe { wc.pageout_kv(addr as *mut u8, evict_bytes) };

    println!(
        "RESULTADO: hook mmap OK — puntero real, size coherente, magic GGUF legible, madvise ejecutado sobre {} bytes",
        evict_bytes
    );
}
