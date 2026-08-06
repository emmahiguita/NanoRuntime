//! Nano Memory Engine — gestión adaptativa de memoria para modelos LLM.
//!
//! Módulo central que integra los 6 componentes del Nano Memory Engine:
//!
//! 1. **HardwareProfiler** — detecta RAM, SSD speed, CPU y estado térmico
//! 2. **CacheAwareLoader** — VMA-safe streaming layer loader (nuevo)
//! 3. **AdaptiveScheduler** — decide qué capas mantener en RAM vs SSD
//! 4. **MemoryPredictor** — predice capas necesarias mediante atención
//! 5. **KvCacheOptimizer** — comprime y evicta KV cache inteligentemente
//! 6. **HierarchicalKvCache** — KV cache jerárquica por ventana (nuevo)
//! 7. **OomGuard** — monitor de OOM Killer con fallback (nuevo)
//! 8. **QualityPreserver** — monitorea perplejidad y ajusta estrategia
//!
//! ## Uso típico
//!
//! ```rust,ignore
//! use nanortime_core::memory_engine::NanoMemoryEngine;
//!
//! let mut engine = NanoMemoryEngine::new(32); // 32 capas del modelo
//! let schedule = engine.compute_schedule(&attention_scores);
//! let report = engine.evaluate_quality(current_perplexity);
//! ```

pub mod adaptive_scheduler;
pub mod auto_config;
pub mod battery_guardian;
pub mod cache_aware_loader;
pub mod cost_scheduler;
pub mod early_exit;
pub mod execution_planner;
pub mod hardware_hal;
pub mod hardware_profiler;
pub mod hierarchical_kv;
pub mod kv_cache_optimizer;
pub mod memory_model;
pub mod memory_predictor;
pub mod model_profile;
pub mod policy_engine;
pub mod quality_preserver;
pub mod storage_manager;
pub mod streaming_ffi;
pub mod gguf_layout;
pub mod os_paginator;
pub mod thermal_controller;

pub use adaptive_scheduler::{AdaptiveScheduler, LayerPriority, MemorySchedule, SchedulingStrategy};
pub use auto_config::{KvCompression, PageStrategy, RuntimeConfig};
pub use battery_guardian::{BatteryConfig, BatteryGuardian, BatteryMode, BatteryStatus};
pub use cache_aware_loader::{CacheAwareLoader, StreamingConfig, LoadResult, can_stream_model, estimate_vma_bytes};
pub use cost_scheduler::{CostScheduler, ScheduleResult, SystemState};
pub use early_exit::EarlyExitController;
pub use execution_planner::{ExecutionPlanner, PlanResult};
pub use hardware_hal::{DeviceProfile, DeviceTier, Platform, StorageBench, classify_tier, detect_platform, profile_device};
pub use hardware_profiler::{DeviceClass, HardwareProfile, HardwareProfiler, ThermalState};
pub use hierarchical_kv::{HierarchicalKvCache, HierarchicalKvConfig, KvSavingsEstimate, KvTier};
pub use kv_cache_optimizer::{CompressionLevel, KvAction, KvCacheOptimizer, TokenImportance};
pub use memory_model::{MemoryEstimate, MemoryModel, ThroughputEstimate};
pub use memory_predictor::{AttentionPattern, MemoryPredictor};
pub use model_profile::{ArchitectureType, ModelProfile};
pub use policy_engine::{Constraints, CostWeights, Decision, PolicyEngine, QosMode};
pub use quality_preserver::{QualityMetrics, QualityPreserver, QualityReport};
pub use storage_manager::{MmapConfig, OffloadCompression, StorageManager};
pub use gguf_layout::{GGUFLayoutAnalyzer, ByteRange, GgufError};
pub use os_paginator::{AccessPattern, OSMemoryPaginator};
pub use thermal_controller::{ThermalAction, ThermalCondition, ThermalController, ThermalReading};

/// Facade del Nano Memory Engine — integra todos los componentes.
///
/// Proporciona una API simple para el Orchestrator y ModelManager.
pub struct NanoMemoryEngine {
    /// Profiler de hardware.
    pub profiler: HardwareProfiler,
    /// Gestor de almacenamiento.
    pub storage: StorageManager,
    /// Scheduler adaptativo de capas.
    pub scheduler: AdaptiveScheduler,
    /// Predictor de capas.
    pub predictor: MemoryPredictor,
    /// Optimizador de KV cache.
    pub kv_optimizer: KvCacheOptimizer,
    /// Preserver de calidad.
    pub quality: QualityPreserver,
    /// Capas actualmente en RAM.
    current_layers_in_ram: Vec<usize>,
}

impl NanoMemoryEngine {
    /// Inicializa el motor de memoria con detección automática de hardware.
    ///
    /// `n_layers`: número de capas del modelo (e.g. 32 para Qwen 7B).
    pub fn new(n_layers: usize) -> Self {
        let mut profiler = HardwareProfiler::new();
        let profile = profiler.profile();

        tracing::info!(
            "NanoMemoryEngine init: {} layers, {} MB RAM, {:.0} MB/s SSD, {:?}",
            n_layers,
            profile.ram_total_mb,
            profile.ssd_speed_mbps,
            profile.device_class
        );

        let storage = StorageManager::new(&profile);
        let scheduler = AdaptiveScheduler::new(&profile, n_layers);
        let predictor = MemoryPredictor::new(20); // 20 token lookback
        let kv_optimizer = KvCacheOptimizer::new(
            profile.ram_available_mb as f64 * 0.25 / 1024.0, // 25% RAM para KV
            "balanced",
        );
        let quality = QualityPreserver::new(15.0); // baseline conservador inicial

        let current_layers_in_ram: Vec<usize> = (0..n_layers).collect();

        Self {
            profiler,
            storage,
            scheduler,
            predictor,
            kv_optimizer,
            quality,
            current_layers_in_ram,
        }
    }

    /// Computa el plan de memoria para el ciclo actual.
    ///
    /// `attention_scores`: scores de atención por capa para el token actual.
    /// Retorna el plan de scheduling (qué offload/prefetch/mantener).
    pub fn compute_schedule(&mut self, attention_scores: &[f32]) -> MemorySchedule {
        // 1. Actualizar RAM disponible
        let ram_available_mb = self.profiler.get_available_ram() as f64;

        // 2. Predecir capas próximas basado en atención actual
        let predicted = self.predictor.predict(attention_scores, 3);

        // 3. Generar schedule
        let schedule = self.scheduler.schedule(
            &self.current_layers_in_ram.clone(),
            &predicted,
            attention_scores,
            ram_available_mb,
        );

        // 4. Actualizar estado interno
        self.current_layers_in_ram = schedule.layers_in_ram.clone();

        schedule
    }

    /// Evalúa la calidad actual y ajusta la estrategia si es necesario.
    ///
    /// `perplexity`: perplejidad medida del token actual.
    /// Retorna el reporte de calidad con recomendaciones.
    pub fn evaluate_quality(&mut self, perplexity: f32) -> QualityReport {
        let report = self.quality.evaluate(perplexity);

        // Si la calidad cae, ajustar el scheduler
        if report.quality_drop_pct > 0.0 {
            self.scheduler.adjust_strategy(report.quality_drop_pct);
        }

        report
    }

    /// Retorna el perfil de hardware detectado.
    pub fn hardware_profile(&mut self) -> HardwareProfile {
        self.profiler.profile()
    }

    /// Retorna las capas actualmente en RAM.
    pub fn layers_in_ram(&self) -> &[usize] {
        &self.current_layers_in_ram
    }

    /// Linux kernel tuning requires root — disabled on stock Android.
    /// Kept as placeholder for future rooted-device optimizations.
    #[allow(dead_code)]
    pub fn tune_linux_system(&self, _kv_cache_swap_mb: usize) -> Result<(), String> {
        tracing::debug!("Kernel tuning skipped (requires root)");
        Ok(())
    }

    /// Retorna un resumen del estado del engine para logging.
    pub fn status_report(&self) -> String {
        let metrics = self.quality.current_metrics();
        format!(
            "[NanoMemoryEngine] layers_in_ram={} strategy={} quality_drop={:.1}% ppl={:.2}",
            self.current_layers_in_ram.len(),
            metrics.strategy,
            metrics.quality_drop_pct,
            metrics.current_perplexity
        )
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_engine_new() {
        let engine = NanoMemoryEngine::new(32);
        assert_eq!(engine.current_layers_in_ram.len(), 32); // Starts with all in RAM
    }

    #[test]
    fn test_compute_schedule_with_attention() {
        let mut engine = NanoMemoryEngine::new(16);
        let scores = vec![0.5f32; 16];
        let schedule = engine.compute_schedule(&scores);
        // At minimum, some layers should be in RAM
        assert!(!schedule.layers_in_ram.is_empty());
        // Total layers should not exceed n_layers
        assert!(schedule.layers_in_ram.len() <= 16);
    }

    #[test]
    fn test_evaluate_quality_no_change() {
        let mut engine = NanoMemoryEngine::new(16);
        engine.quality.set_baseline(10.0);
        let report = engine.evaluate_quality(10.0);
        assert!(report.quality_drop_pct.abs() < 0.5);
        assert!(!report.protect_critical);
    }

    #[test]
    fn test_evaluate_quality_triggers_conservative() {
        let mut engine = NanoMemoryEngine::new(16);
        engine.quality.set_baseline(10.0);
        // Feed high perplexity into the window first
        for _ in 0..30 {
            engine.quality.feed_perplexity(15.0);
        }
        let report = engine.evaluate_quality(15.0);
        assert_eq!(report.strategy, "conservative");
    }

    #[test]
    fn test_status_report_format() {
        let engine = NanoMemoryEngine::new(8);
        let report = engine.status_report();
        assert!(report.contains("NanoMemoryEngine"));
        assert!(report.contains("layers_in_ram"));
    }

    #[test]
    fn test_layers_in_ram_updated_after_schedule() {
        let mut engine = NanoMemoryEngine::new(32);
        // Set known layer sizes so scheduler can make decisions
        for i in 0..32 {
            engine.scheduler.set_layer_size(i, 200.0); // 200MB each → forces offload
        }
        let scores = vec![0.1f32; 32];
        let schedule = engine.compute_schedule(&scores);
        assert_eq!(engine.layers_in_ram(), &schedule.layers_in_ram);
    }
}
