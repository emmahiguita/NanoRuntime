//! Nano Memory Engine — gestión adaptativa de memoria para modelos LLM.
//!
//! ## Estado de conexión (verificado con grep de callers, no impresión)
//!
//! **Activos en producción** (callers reales en orchestrator/model_manager):
//! - `HardwareProfiler` / `hardware_hal::profile_device` — detección de RAM/SSD/CPU
//! - `ExecutionPlanner` + `MemoryModel` — planificación V2 (memory_manager.rs)
//! - `HierarchicalKvCache` — KV cache jerárquica (model_manager.rs)
//! - `RuntimeMetricsCollector` — faults/PSS/PSI reales (model_manager.rs)
//! - `WorkingSetEstimator` — detección de thrashing con señales reales
//! - `ThermalController` + `BatteryGuardian` — (orchestrator)
//! - `OomGuard` — /proc/self/oom_score (facade)
//! - `CacheAwareLoader` + `AdaptiveScheduler` — vía ExecutionPlanner
//! - `NanoModelIndex` / `gguf_layout` — parser GGUF real, standalone
//!   (lee el header del archivo, sin hooks de llama.cpp) — tamaños de
//!   capa REALES inyectados en model_manager.rs
//!
//! **Dormidos** (`feature = "unstable"`) — esperan hooks que no existen:
//! mmap pointer de llama.cpp (ResidencyManager/OSMemoryPaginator/StorageManager),
//! atención por capa (AdaptiveKvPolicy/MemoryPredictor), NGRAM
//! (NgramSchedulerIntegration), perplejidad de referencia
//! (QualityPreserver). Sin esos hooks, conectarlos sería simulación.
//!
//! ## Uso típico
//!
//! ```rust,ignore
//! use nanortime_core::memory_engine::NanoMemoryEngine;
//!
//! let mut engine = NanoMemoryEngine::new(32); // 32 capas del modelo
//! let snapshot = engine.check_oom();          // OOM real antes de inferir
//! ```

pub mod adaptive_scheduler;
pub mod auto_config;
pub mod battery_guardian;
pub mod cache_aware_loader;
pub mod execution_planner;
pub mod hardware_hal;
pub mod hardware_profiler;
pub mod hierarchical_kv;
pub mod memory_model;
pub mod model_profile;
pub mod oom_guard;
pub mod runtime_metrics;
pub mod thermal_controller;
pub mod traits;
pub mod types;
pub mod working_set_estimator;
pub mod runtime_planner;
// Activo de verdad: CacheAwareLoader lo usa con su propio puntero mmap real
// (no es hook de llama.cpp — evicción quirúrgica MADV_COLD/PAGEOUT antes de munmap).
pub mod weight_cache_aware;
// Activo de verdad: parser standalone — solo lee el header GGUF del
// archivo (File::open + seek), no necesita mmap pointer de llama.cpp.
pub mod gguf_layout;

// ── Dormidos reales: esperan hooks que no existen (atención por capa, NGRAM) ──
#[cfg(feature = "unstable")]
pub mod adaptive_kv_policy;
#[cfg(feature = "unstable")]
pub mod kv_cache_optimizer;
#[cfg(feature = "unstable")]
pub mod memory_predictor;
#[cfg(feature = "unstable")]
pub mod ngram_scheduler_integration;

// ── Despertados: el hook mmap de llama.cpp ya existe → paginación OS real ──
pub mod async_prefetch;
pub mod os_paginator;
pub mod policy_engine;
pub mod quality_preserver;
pub mod residency_manager;
pub mod storage_manager;
pub mod streaming_ffi;
pub mod utility;

// ── Public API (primary exports used by orchestrator & model_manager) ──
pub use auto_config::{KvCompression, PageStrategy, RuntimeConfig};
pub use battery_guardian::{BatteryConfig, BatteryGuardian, BatteryMode};
pub use cache_aware_loader::{can_stream_model, CacheAwareLoader, StreamingConfig};
#[allow(deprecated)]
pub use execution_planner::{ExecutionPlanner, PlanResult};
pub use hardware_hal::{classify_tier, profile_device, DeviceProfile, DeviceTier};
pub use oom_guard::{OomGuard, OomRisk, OomSnapshot};
pub use thermal_controller::{ThermalAction, ThermalCondition, ThermalController, ThermalReading};
pub use types::{ByteRange, QosMode};

// ── Internal types (re-exported for advanced use / testing) ──
pub use adaptive_scheduler::{
    AdaptiveScheduler, LayerPriority, MemorySchedule, SchedulingStrategy,
};
pub use battery_guardian::BatteryStatus;
pub use cache_aware_loader::{estimate_vma_bytes, LoadResult};
pub use gguf_layout::{
    GgufError, LayerInfo, NanoModelIndex, PageSizeInfo, QuantizationType, TensorInfo,
    WorkingSetEstimate,
};
pub use hardware_hal::StorageBench;
pub use hardware_profiler::{DeviceClass, HardwareProfile, HardwareProfiler, ThermalState};
pub use hierarchical_kv::{HierarchicalKvCache, HierarchicalKvConfig, KvSavingsEstimate, KvTier};
pub use memory_model::{MemoryEstimate, MemoryModel, ThroughputEstimate};
pub use model_profile::{ArchitectureType, ModelProfile};
pub use runtime_metrics::{RuntimeMetricsCollector, RuntimeMetrics, MemoryPressureMetrics, IoMetrics, PsiMetrics, CacheMetrics, ThroughputMetrics, NgramMetrics};
pub use working_set_estimator::{WorkingSetEstimator, WorkingSetBreakdown, ThrashingState, ThrashingDetection, ThrashingFactor, ThrashingAction};
pub use runtime_planner::{
    Backend, ComputePlan, InferenceBudget, LatencyClass, Measurements, MemoryPlan,
    ModelCandidate, ModelPlan, Observations, PrivacyClass, QuantLevel, RiskLevel, RuntimePlan,
    RuntimePlanner, Viability, ViabilityReport,
};

// ── Re-exports de módulos dormidos (atención por capa / NGRAM: sin hook) ──
#[cfg(feature = "unstable")]
pub use adaptive_kv_policy::{AdaptiveKvPolicy, AdaptiveKvConfig, AdaptiveKvTier, TokenImportance as AdaptiveTokenImportance, TokenAccessPattern, AdaptiveKvStats};
#[cfg(feature = "unstable")]
pub use kv_cache_optimizer::{CompressionLevel, KvAction, KvCacheOptimizer, TokenImportance};
#[cfg(feature = "unstable")]
pub use memory_predictor::{AttentionPattern, MemoryPredictor};
#[cfg(feature = "unstable")]
pub use ngram_scheduler_integration::{NgramSchedulerIntegration, NgramSchedulingDecision, StrategyAdjustment};

// ── Re-exports de módulos despertados (hook mmap real) ──
pub use async_prefetch::{AsyncPrefetchManager, DoubleBuffer, BufferState, PrefetchStats, PrefetchResult};
pub use hardware_hal::{detect_platform, Platform};
pub use os_paginator::{AccessPattern, OSMemoryPaginator};
pub use policy_engine::{Constraints, CostWeights, Decision, PolicyEngine};
pub use quality_preserver::{QualityMetrics, QualityPreserver, QualityReport};
pub use residency_manager::{ResidencyManager, ResidencyState, ResidencyPolicy, ResidencyInfo, ResidencyStats};
pub use storage_manager::{MmapConfig, OffloadCompression, StorageManager};
pub use utility::{best_window, liveness_rate, pressure_penalty, useful_throughput, utility, SweepPoint, UtilityWeights};

// ── Facade ─────────────────────────────────────────────────────────────
// (imports cfg(unstable) eliminados: los `pub use` de arriba ya traen
// MemorySchedule, MemoryPredictor, KvCacheOptimizer, QualityPreserver,
// QualityReport y StorageManager al namespace de este módulo)

/// Facade del Nano Memory Engine — integra los componentes activos.
///
/// En build default integra solo lo conectado de verdad (profiler, scheduler
/// por RAM, OOM guard). Los componentes que esperan hooks de llama.cpp
/// (predictor por atención, KV optimizer, quality preserver, storage manager)
/// se activan con `feature = "unstable"`.
pub struct NanoMemoryEngine {
    /// Profiler de hardware.
    pub profiler: HardwareProfiler,
    /// Scheduler adaptativo de capas.
    pub scheduler: AdaptiveScheduler,
    /// OOM Guard — monitors /proc/self/oom_score and triggers survival mode.
    pub oom_guard: OomGuard,
    /// Gestor de almacenamiento (requiere mmap pointer de llama.cpp).
    #[cfg(feature = "unstable")]
    pub storage: StorageManager,
    /// Predictor de capas (requiere atención por capa, hook inexistente).
    #[cfg(feature = "unstable")]
    pub predictor: MemoryPredictor,
    /// Optimizador de KV cache (sin acceso a la KV real).
    #[cfg(feature = "unstable")]
    pub kv_optimizer: KvCacheOptimizer,
    /// Preserver de calidad (requiere perplejidad de referencia).
    #[cfg(feature = "unstable")]
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

        let scheduler = AdaptiveScheduler::new(&profile, n_layers);
        let oom_guard = OomGuard::new();

        #[cfg(feature = "unstable")]
        let (storage, predictor, kv_optimizer, quality) = {
            let storage = StorageManager::new(&profile);
            let predictor = MemoryPredictor::new(20); // 20 token lookback
            let kv_optimizer = KvCacheOptimizer::new(
                profile.ram_available_mb as f64 * 0.25 / 1024.0, // 25% RAM para KV
                "balanced",
            );
            let quality = QualityPreserver::new(15.0); // baseline conservador inicial
            (storage, predictor, kv_optimizer, quality)
        };

        let current_layers_in_ram: Vec<usize> = (0..n_layers).collect();

        Self {
            profiler,
            scheduler,
            oom_guard,
            #[cfg(feature = "unstable")]
            storage,
            #[cfg(feature = "unstable")]
            predictor,
            #[cfg(feature = "unstable")]
            kv_optimizer,
            #[cfg(feature = "unstable")]
            quality,
            current_layers_in_ram,
        }
    }

    /// Computa el plan de memoria para el ciclo actual.
    ///
    /// `attention_scores`: scores por capa. En build default se ignoran
    /// (no hay señal de atención real sin hook en llama.cpp — fabricar
    /// predicciones a partir de probabilidades de tokens sería simulación);
    /// el scheduler decide por RAM disponible y prioridad de capas.
    /// Con `feature = "unstable"` se usa el MemoryPredictor.
    #[cfg(feature = "unstable")]
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

    /// Computa el plan de memoria para el ciclo actual (build default).
    ///
    /// Sin predictor: `predicted_layers` vacío — el scheduler decide por
    /// RAM disponible y prioridad de capas, sin bonus de predicción.
    ///
    /// Solo existe en tests: en producción default no hay caller — el
    /// lazo del engine completo (compute_schedule → apply_schedule →
    /// evaluate_quality) requiere el actuador StorageManager, que espera
    /// un mmap pointer de llama.cpp inexistente (feature = "unstable").
    #[cfg(all(not(feature = "unstable"), test))]
    pub fn compute_schedule(&mut self, attention_scores: &[f32]) -> crate::memory_engine::adaptive_scheduler::MemorySchedule {
        let ram_available_mb = self.profiler.get_available_ram() as f64;

        let predicted: Vec<usize> = Vec::new();
        let schedule = self.scheduler.schedule(
            &self.current_layers_in_ram.clone(),
            &predicted,
            attention_scores,
            ram_available_mb,
        );

        self.current_layers_in_ram = schedule.layers_in_ram.clone();

        schedule
    }

    /// Stores the model file size (MB) for memory budget calculations.
    /// Called by ModelManager when a model is loaded.
    ///
    /// Distributes the total file size evenly across ALL layers so the
    /// scheduler has accurate per-layer memory estimates. Previously only
    /// set the first top-priority layer, leaving the remaining layers at
    /// 0.0 MB — causing the scheduler to severely underestimate memory
    /// needs for multi-layer models (32-80 layers in 1B-7B models).
    pub fn set_model_memory(&mut self, file_size_mb: u64) {
        tracing::debug!(
            "NanoMemoryEngine: model file size set to {} MB",
            file_size_mb
        );
        let n_layers = self.current_layers_in_ram.len().max(1);
        let per_layer_mb = file_size_mb as f64 / n_layers as f64;
        for i in 0..n_layers {
            self.scheduler.set_layer_size(i, per_layer_mb);
        }
        tracing::debug!(
            "NanoMemoryEngine: distributed {} MB across {} layers ({:.1} MB/layer)",
            file_size_mb,
            n_layers,
            per_layer_mb
        );
    }

    /// Sets the real per-layer memory size (MB) parsed from the GGUF layout.
    /// Called by ModelManager after loading a model — replaces the uniform
    /// distribution with the actual size of each layer.
    pub fn set_layer_size(&mut self, layer: usize, size_mb: f64) {
        self.scheduler.set_layer_size(layer, size_mb);
    }

    /// Evalúa la calidad actual y ajusta la estrategia si es necesario.
    ///
    /// `perplexity`: perplejidad medida del token actual.
    /// Retorna el reporte de calidad con recomendaciones.
    #[cfg(feature = "unstable")]
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
    #[cfg(feature = "unstable")]
    pub fn status_report(&self) -> String {
        let metrics = self.quality.current_metrics();
        format!(
            "[NanoMemoryEngine] layers_in_ram={} strategy={} quality_drop={:.1}% ppl={:.2} survival={} peak_oom={}",
            self.current_layers_in_ram.len(),
            metrics.strategy,
            metrics.quality_drop_pct,
            metrics.current_perplexity,
            self.oom_guard.is_survival_active(),
            self.oom_guard.peak_score(),
        )
    }

    /// Retorna un resumen del estado del engine para logging (build default).
    /// Vivo en producción: model_manager lo registra en cada ciclo de
    /// métricas (survival mode y OOM score son señal real).
    #[cfg(not(feature = "unstable"))]
    pub fn status_report(&self) -> String {
        format!(
            "[NanoMemoryEngine] layers_in_ram={} survival={} peak_oom={}",
            self.current_layers_in_ram.len(),
            self.oom_guard.is_survival_active(),
            self.oom_guard.peak_score(),
        )
    }

    /// Sample OOM state and return whether survival mode should activate.
    /// Call before each inference cycle to check memory pressure.
    pub fn check_oom(&mut self) -> OomSnapshot {
        self.oom_guard.sample()
    }

    /// Check if the OOM score is trending worse.
    pub fn is_oom_trending_worse(&self) -> bool {
        self.oom_guard.is_trending_worse()
    }

    /// Get the OOM guard reference for detailed queries.
    pub fn oom_guard(&self) -> &OomGuard {
        &self.oom_guard
    }

    pub fn oom_guard_mut(&mut self) -> &mut OomGuard {
        &mut self.oom_guard
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

    #[cfg(feature = "unstable")]
    #[test]
    fn test_evaluate_quality_no_change() {
        let mut engine = NanoMemoryEngine::new(16);
        engine.quality.set_baseline(10.0);
        let report = engine.evaluate_quality(10.0);
        assert!(report.quality_drop_pct.abs() < 0.5);
        assert!(!report.protect_critical);
    }

    #[cfg(feature = "unstable")]
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
