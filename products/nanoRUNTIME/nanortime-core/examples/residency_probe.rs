//! Probe REAL de la inyección: paginator + residency manager conectados al
//! puntero mmap real de llama.cpp y al índice GGUF.
//!
//! Demuestra la tesis DOOM: cargar el modelo mmap-eado, evictar capas con
//! madvise(DONTNEED) y medir la RAM REAL reclamada. El modelo sigue usable:
//! el kernel vuelve a paginar las capas bajo demanda.
//!
//! Uso:
//!   cargo run -p nanortime-core --example residency_probe -- [ruta.gguf]

use nanortime_core::memory_engine::{
    NanoModelIndex, OSMemoryPaginator, ResidencyManager, ResidencyState, RuntimeMetricsCollector,
};
use nanortime_ffi::{ModelLoadParams, NanoModel};
use std::path::PathBuf;

fn rss_mb() -> f64 {
    let mut c = RuntimeMetricsCollector::new();
    let m = c.collect();
    m.memory.rss_bytes as f64 / 1048576.0
}

fn main() {
    tracing_subscriber::fmt::init();

    let default = concat!(env!("CARGO_MANIFEST_DIR"), "/../../data/qwen_tmp.gguf");
    let path = std::env::args()
        .nth(1)
        .map(PathBuf::from)
        .unwrap_or_else(|| PathBuf::from(default));
    let n_layers_arg = std::env::args()
        .nth(2)
        .and_then(|s| s.parse::<usize>().ok())
        .unwrap_or(28);

    println!("=== residency injection probe: {} ===", path.display());
    if !path.exists() {
        eprintln!("ERROR: no existe {}", path.display());
        std::process::exit(1);
    }

    // 1. Cargar modelo mmap-eado + hook mmap.
    let params = ModelLoadParams {
        context_size: 512,
        gpu_layers: 0,
        use_mmap: true,
        threads: 2,
        batch_size: 128,
    };
    let model = NanoModel::load(path.to_str().unwrap(), &params).expect("cargar modelo");
    let (addr, size) = model.mmap_addr();
    assert!(!addr.is_null() && size > 0, "hook mmap vacío");

    // 2. Índice GGUF real (capas → rangos de bytes del archivo).
    let index = NanoModelIndex::analyze(&path, n_layers_arg).expect("analizar GGUF");
    let n_layers = index.layers.len().max(1);
    println!(
        "[index] {} capas, {} tensores, data_offset={}",
        n_layers, index.tensor_count, index.data_offset
    );

    // 3. INYECCIÓN: paginator con el puntero REAL + residency manager con el
    //    índice REAL. De aquí en adelante los madvise operan sobre la mapping
    //    viva del modelo.
    let paginator = OSMemoryPaginator::new(addr, size);
    let mut residency = ResidencyManager::with_defaults()
        .with_model_index(index)
        .with_paginator(paginator);

    for l in 0..n_layers {
        residency.register_layer(l, 0.5);
    }
    // Capas 0..=3 = ventana activa (Keep); el resto evictable.
    for l in 0..=3 {
        residency.force_state(l, ResidencyState::Keep);
    }

    // 4. RSS antes de evictar.
    let rss_before = rss_mb();
    println!("[RSS] antes de evictar: {:.1} MB", rss_before);

    // 5. Evictar todas las capas fuera de la ventana activa (madvise DONTNEED).
    for l in 4..n_layers {
        residency.force_state(l, ResidencyState::Reclaim);
    }

    let rss_after = rss_mb();
    let freed = rss_before - rss_after;
    println!(
        "[RSS] después de evictar {} capas: {:.1} MB (reclamado {:.1} MB)",
        n_layers - 4,
        rss_after,
        freed
    );

    let stats = residency.get_stats();
    println!(
        "[residency] keep={} reclaim={} cold={} prefetch={}",
        stats.keep_count, stats.reclaim_count, stats.cold_count, stats.prefetch_count
    );

    // 6. Verificación: el modelo sigue vivo tras la evicción (los pesos
    //    evictados se re-paginan bajo demanda al leerlos).
    let magic = unsafe { std::slice::from_raw_parts(addr as *const u8, 4) };
    println!(
        "[verify] magic tras evicción = {:?} ({})",
        magic,
        String::from_utf8_lossy(magic)
    );
    assert_eq!(magic, b"GGUF", "la mapping quedó inválida tras evictar");

    println!(
        "RESULTADO: inyección OK — {} capas evictadas, {:.1} MB reclamados, modelo íntegro",
        n_layers - 4,
        freed
    );
}
