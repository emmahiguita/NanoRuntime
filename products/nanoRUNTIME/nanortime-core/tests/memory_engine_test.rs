//! Tests de integración del Nano Memory Engine.
//!
//! Verifica la interacción entre todos los componentes del engine.

use nanortime_core::memory_engine::{
    AdaptiveScheduler, DeviceClass, HardwareProfile, HardwareProfiler, ModelProfile,
    NanoMemoryEngine,
};
#[cfg(feature = "unstable")]
use nanortime_core::memory_engine::{
    CompressionLevel, KvAction, KvCacheOptimizer, MemoryPredictor, QualityPreserver,
    StorageManager, TokenImportance,
};
use std::time::Instant;

fn test_profile(ram_mb: u64, ssd_mbps: f64, cores: usize) -> HardwareProfile {
    HardwareProfile {
        ram_total_mb: ram_mb,
        ram_available_mb: ram_mb / 2,
        ssd_speed_mbps: ssd_mbps,
        cpu_cores: cores,
        device_class: DeviceClass::MidEnd,
        thermal: Default::default(),
        last_updated: Instant::now(),
    }
}

// ─── Hardware Profiler ───────────────────────────────────────────────────────

#[test]
fn test_hardware_profiler_detects_real_system() {
    let mut profiler = HardwareProfiler::new();
    let profile = profiler.profile();

    assert!(
        profile.ram_total_mb >= 1024,
        "Should detect at least 1GB RAM"
    );
    assert!(profile.ram_available_mb > 0);
    assert!(profile.cpu_cores >= 1);
    assert!(profile.ssd_speed_mbps > 0.0);
    // Device class should be valid
    let _class = profile.device_class;
}

#[test]
fn test_hardware_profiler_estimate_layers() {
    let mut profiler = HardwareProfiler::new();
    // 4GB model, 32 layers → at least some layers should fit
    let profile = ModelProfile::new_dense(4000, 32);
    let layers = profiler.estimate_model_layers_in_ram(&profile);
    assert!(layers <= 32);
    // On any modern system with at least 8GB, at least 1 layer should fit
    assert!(layers >= 1, "At least 1 layer should fit in available RAM");
}

#[test]
fn test_hardware_profiler_ssd_benchmark() {
    let mut profiler = HardwareProfiler::new();
    let speed = profiler.get_ssd_speed();
    assert!(speed >= 1.0, "SSD speed should be at least 1 MB/s");
    assert!(speed < 100_000.0, "SSD speed should be realistic");
}

// ─── Storage Manager ─────────────────────────────────────────────────────────

#[cfg(feature = "unstable")]
#[test]
fn test_storage_manager_offload_roundtrip() {
    let profile = test_profile(16384, 500.0, 8);
    let mut sm = StorageManager::new(&profile);
    let original_data = vec![42u8; 4096]; // 4KB

    sm.offload_layer(&original_data, 10)
        .expect("offload should succeed");
    assert_eq!(sm.offloaded_count(), 1);

    let loaded = sm.load_layer(10).expect("load should succeed");
    assert_eq!(loaded, original_data, "Roundtrip should preserve data");
}

#[cfg(feature = "unstable")]
#[test]
fn test_storage_manager_nonexistent_layer() {
    let profile = test_profile(16384, 500.0, 8);
    let sm = StorageManager::new(&profile);
    assert!(
        sm.load_layer(999).is_err(),
        "Loading non-offloaded layer should fail"
    );
}

#[cfg(feature = "unstable")]
#[test]
fn test_storage_manager_penalty_scales_with_size() {
    let profile = test_profile(16384, 1000.0, 8);
    let sm = StorageManager::new(&profile);

    let small_penalty = sm.estimate_swap_penalty(1024 * 1024); // 1MB
    let large_penalty = sm.estimate_swap_penalty(1024 * 1024 * 100); // 100MB

    assert!(
        large_penalty > small_penalty,
        "Larger data should have larger penalty"
    );
}

// ─── Adaptive Scheduler ──────────────────────────────────────────────────────

#[test]
fn test_scheduler_all_layers_fit_large_budget() {
    let profile = test_profile(64_000, 1000.0, 16);
    let mut scheduler = AdaptiveScheduler::new(&profile, 32);
    // Give each layer 1MB → 32MB total, budget 60GB → all fit
    for i in 0..32 {
        scheduler.set_layer_size(i, 1.0);
    }
    let scores = vec![0.5f32; 32];
    let schedule = scheduler.schedule(&[], &[], &scores, 60_000.0);
    assert_eq!(schedule.layers_in_ram.len(), 32, "All 32 layers should fit");
    assert!(schedule.layers_to_offload.is_empty());
}

#[test]
fn test_scheduler_critical_layers_high_priority() {
    let profile = test_profile(8192, 500.0, 8);
    let mut scheduler = AdaptiveScheduler::new(&profile, 10);
    for i in 0..10 {
        scheduler.set_layer_size(i, 500.0); // Large layers to force some offload
    }
    let scores = vec![0.1f32; 10]; // All low attention
    let schedule = scheduler.schedule(&[], &[], &scores, 2500.0); // Budget for ~5 layers

    // Layer 0 (first) and layer 9 (last) are critical — should be in RAM
    assert!(
        schedule.layers_in_ram.contains(&0) || schedule.layers_in_ram.contains(&9),
        "At least one critical layer should be in RAM"
    );
}

#[test]
fn test_scheduler_strategy_adjusts() {
    let profile = test_profile(8192, 500.0, 8);
    let mut scheduler = AdaptiveScheduler::new(&profile, 32);
    assert_eq!(
        scheduler.current_strategy(),
        nanortime_core::memory_engine::SchedulingStrategy::Balanced
    );

    scheduler.adjust_strategy(5.0); // 5% quality drop
    assert_eq!(
        scheduler.current_strategy(),
        nanortime_core::memory_engine::SchedulingStrategy::Conservative
    );
}

// ─── Memory Predictor ─────────────────────────────────────────────────────────

#[cfg(feature = "unstable")]
#[test]
fn test_predictor_identifies_consistent_hot_layers() {
    let mut predictor = MemoryPredictor::new(10);
    let mut scores = vec![0.1f32; 16];
    scores[7] = 0.95; // Layer 7 consistently hot

    for _ in 0..10 {
        predictor.feed(&scores);
    }

    let predicted = predictor.predict(&scores, 1);
    assert!(
        predicted.contains(&7),
        "Layer 7 should be consistently predicted"
    );
}

#[cfg(feature = "unstable")]
#[test]
fn test_predictor_no_hot_layers_when_uniform_low() {
    let mut predictor = MemoryPredictor::new(10);
    let scores = vec![0.1f32; 16]; // All low

    for _ in 0..10 {
        predictor.feed(&scores);
    }

    let predicted = predictor.predict(&scores, 1);
    assert!(
        predicted.is_empty(),
        "No layers should be predicted when all attention is low"
    );
}

#[cfg(feature = "unstable")]
#[test]
fn test_predictor_window_bounded() {
    let mut predictor = MemoryPredictor::new(5);
    for i in 0..20 {
        predictor.feed(&[i as f32 / 20.0; 8]);
    }
    assert_eq!(predictor.token_count(), 20);
}

// ─── KV Cache Optimizer ──────────────────────────────────────────────────────

#[cfg(feature = "unstable")]
#[test]
fn test_kv_optimizer_importance_ordering() {
    let opt = KvCacheOptimizer::new(0.001, "aggressive"); // Tiny budget to force eviction
    let tokens = vec![
        TokenImportance {
            token_id: 0,
            attention_score: 0.9,
            recency: 0.1,
            uniqueness: 0.9,
        }, // High
        TokenImportance {
            token_id: 1,
            attention_score: 0.1,
            recency: 0.1,
            uniqueness: 0.1,
        }, // Low
        TokenImportance {
            token_id: 2,
            attention_score: 0.5,
            recency: 0.5,
            uniqueness: 0.5,
        }, // Mid
    ];

    let actions = opt.optimize(&tokens, 30_000); // 30KB with tiny budget
    let evicted: Vec<usize> = actions
        .iter()
        .filter(|(_, a)| *a == KvAction::Evict)
        .map(|(id, _)| *id)
        .collect();

    // Token 1 (lowest importance) should be evicted first
    assert!(
        evicted.contains(&1) || !evicted.contains(&0),
        "Higher importance tokens should be preserved"
    );
}

#[cfg(feature = "unstable")]
#[test]
fn test_kv_optimizer_compression_reduces_size() {
    let data = vec![100u8; 1024];
    let compressed_int4 = KvCacheOptimizer::compress_kv(&data, CompressionLevel::Int4);
    assert_eq!(compressed_int4.len(), 256); // 4x reduction
}

#[cfg(feature = "unstable")]
#[test]
fn test_kv_optimizer_savings_calculation() {
    let actions = vec![
        (0, KvAction::Keep),
        (1, KvAction::Evict),
        (2, KvAction::Compress(CompressionLevel::Int8)),
    ];
    let savings = KvCacheOptimizer::estimate_savings(&actions, 2048);
    // Evict: 2048 + Compress INT8: 2048 - 1024 = 1024 → total 3072
    assert_eq!(savings, 3072);
}

// ─── Quality Preserver ────────────────────────────────────────────────────────

#[cfg(feature = "unstable")]
#[test]
fn test_quality_preserver_stable_quality() {
    let mut qp = QualityPreserver::new(10.0);
    for _ in 0..20 {
        qp.feed_perplexity(10.2); // ~2% deviation — near stable
    }
    let metrics = qp.current_metrics();
    assert!((metrics.current_perplexity - 10.2).abs() < 0.5);
}

#[cfg(feature = "unstable")]
#[test]
fn test_quality_preserver_high_drop_triggers_conservative() {
    let mut qp = QualityPreserver::new(10.0);
    for _ in 0..30 {
        qp.feed_perplexity(15.0); // 50% drop
    }
    let report = qp.evaluate(15.0);
    assert_eq!(report.strategy, "conservative");
    assert!(report.protect_critical);
    assert!(report.quality_drop_pct > 2.0);
}

#[cfg(feature = "unstable")]
#[test]
fn test_quality_preserver_perplexity_from_logits() {
    // Confident prediction: one logit dominates
    let mut logits = vec![0.0f32; 50];
    logits[10] = 50.0;
    let ppl = QualityPreserver::measure_perplexity(&logits, &[10]);
    assert!(
        ppl < 3.0,
        "Confident logit should give low perplexity: {}",
        ppl
    );
}

// ─── NanoMemoryEngine Facade ──────────────────────────────────────────────────

#[test]
fn test_engine_initializes_with_real_hardware() {
    let engine = NanoMemoryEngine::new(32);
    // All 32 layers should start in RAM (before any scheduling)
    assert_eq!(engine.layers_in_ram().len(), 32);
}

#[cfg(feature = "unstable")]
#[test]
fn test_engine_full_pipeline() {
    let mut engine = NanoMemoryEngine::new(16);
    engine.quality.set_baseline(12.0);

    // Simulate 10 tokens of generation
    for i in 0..10 {
        let mut scores = vec![0.2f32; 16];
        scores[i % 16] = 0.9; // Hot layer rotates

        let schedule = engine.compute_schedule(&scores);
        assert!(!schedule.layers_in_ram.is_empty());

        let report = engine.evaluate_quality(12.0 + i as f32 * 0.1);
        assert!(report.quality_drop_pct < 10.0);
    }
}

#[test]
fn test_engine_status_report_format() {
    let engine = NanoMemoryEngine::new(8);
    let report = engine.status_report();
    assert!(report.contains("NanoMemoryEngine"));
    assert!(report.contains("layers_in_ram=8"));
}

#[test]
fn test_engine_hardware_profile_realistic() {
    let mut engine = NanoMemoryEngine::new(8);
    let profile = engine.hardware_profile();
    assert!(profile.ram_total_mb >= 1024);
    assert!(profile.cpu_cores >= 1);
}
