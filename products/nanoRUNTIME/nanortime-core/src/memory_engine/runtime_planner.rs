//! Runtime Planner â€” the OS-like control plane.
//!
//! Materializa la filosofÃ­a de "administrar la inferencia como Linux administra
//! un proceso": en vez de obligar al hardware a ejecutar un modelo fijo, el
//! planner recibe un **presupuesto declarativo** y decide quÃ© modelo, cuÃ¡nto
//! contexto, quÃ© compresiÃ³n de KV, quÃ© backend y cuÃ¡ntos cores puede
//! permitirse. Cuando las condiciones del dispositivo cambian, cambia la
//! estrategia.
//!
//! ## El lazo
//!
//! ```text
//! OBSERVE â”€â”€â–º PLAN â”€â”€â–º EXECUTE â”€â”€â–º MEASURE â”€â”€â–º ADAPT â”€â”€â”
//!    â–²                                                  â”‚
//!    â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜
//! ```
//!
//! - `Observations::sample()` = OBSERVE (seÃ±ales REALES: RAM, faults, PSI,
//!   thermal, baterÃ­a, thrashing).
//! - `RuntimePlanner::plan()` = PLAN (budget â†’ Memory/Compute/Model plan).
//! - el caller ejecuta el plan contra `ModelManager`.
//! - `Measurements` = MEASURE (tok/s, ttft, calidad, fault_rate reales).
//! - `RuntimePlanner::adapt()` = ADAPT (re-planificar con las mediciones).
//!
//! Todo usa seÃ±ales reales del OS. Nada fabricado.

use std::fmt;
use std::sync::{Arc, Mutex};

use crate::memory_engine::auto_config::{KvCompression, PageStrategy};
use crate::memory_engine::battery_guardian::{BatteryGuardian, BatteryMode};
use crate::memory_engine::benchmark_store::{
    BenchmarkStore, DeviceFingerprint, MeasuredExecutionProfile, ModelFingerprint, ResolutionLevel,
};
use crate::memory_engine::hardware_hal::{profile_device, DeviceProfile, DeviceTier};
use crate::memory_engine::memory_model::MemoryModel;
use crate::memory_engine::runtime_metrics::{RuntimeMetrics, RuntimeMetricsCollector};
use crate::memory_engine::thermal_controller::{ThermalCondition, ThermalController};
use crate::memory_engine::working_set_estimator::{ThrashingState, WorkingSetEstimator};

// â”€â”€ Budget: contrato declarativo â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

/// Latency class requested by the caller.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum LatencyClass {
    /// Conversational â€” target < ~1s first token, â‰¥ ~5 tok/s.
    Interactive,
    /// Long-form generation â€” latency less critical, quality first.
    Batch,
    /// Offline jobs â€” energy/quality over latency.
    Background,
}

/// Privacy policy for routing/backends.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum PrivacyClass {
    /// Everything stays on-device. No cloud, ever.
    LocalOnly,
    /// Prefer local; cloud allowed only when local cannot meet quality.
    LocalFirst,
    /// Cloud allowed freely.
    AllowCloud,
}

/// Declarative inference budget â€” the "sistema operativo" contract.
///
/// The planner NEVER exceeds these bounds. It may deliver *less* than asked
/// if the device cannot afford it (liveness > maximum throughput).
#[derive(Debug, Clone)]
pub struct InferenceBudget {
    /// RAM ceiling (MB) for weights + KV + runtime.
    pub max_memory_mb: u64,
    /// Thermal ceiling (Â°C). Above this, compute degrades.
    pub max_temperature_c: f32,
    /// Minimum acceptable quality (0.0â€“1.0) as confidence/probability proxy.
    pub min_quality: f32,
    /// Privacy policy.
    pub privacy: PrivacyClass,
    /// Latency class.
    pub latency: LatencyClass,
}

impl Default for InferenceBudget {
    fn default() -> Self {
        Self {
            max_memory_mb: 2_500,
            max_temperature_c: 42.0,
            min_quality: 0.80,
            privacy: PrivacyClass::LocalFirst,
            latency: LatencyClass::Interactive,
        }
    }
}

// â”€â”€ Model catalog â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

/// Quantization level (memory multiplier relative to Q4).
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum QuantLevel {
    Q4,
    Q5,
    Q8,
}

impl QuantLevel {
    pub fn label(&self) -> &'static str {
        match self {
            QuantLevel::Q4 => "Q4_K_M",
            QuantLevel::Q5 => "Q5_K_M",
            QuantLevel::Q8 => "Q8_0",
        }
    }
}

impl fmt::Display for QuantLevel {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{}", self.label())
    }
}

/// A concrete model in the candidate pool (small, realistic catalog).
#[derive(Debug, Clone)]
pub struct ModelCandidate {
    /// Human label ("1.5B", "3B", "7B").
    pub label: String,
    /// Parameter count in billions.
    pub params_b: f32,
    /// GGUF file size in MB.
    pub size_mb: u64,
    /// Number of transformer layers.
    pub n_layers: usize,
    /// Quantization of this candidate.
    pub quant: QuantLevel,
}

// â”€â”€ Plan output (Memory/Compute/Model) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

/// Execution backend.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Backend {
    Cpu,
    Vulkan,
    Npu,
}

impl fmt::Display for Backend {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Backend::Cpu => write!(f, "CPU"),
            Backend::Vulkan => write!(f, "Vulkan"),
            Backend::Npu => write!(f, "NPU"),
        }
    }
}

impl Backend {
    fn as_str(self) -> &'static str {
        match self {
            Backend::Cpu => "cpu",
            Backend::Vulkan => "vulkan",
            Backend::Npu => "npu",
        }
    }
}

/// Perfil de rendimiento de un backend en un dispositivo concreto.
///
/// `available` ≠ `recommended`: un backend puede estar disponible pero ser
/// más lento que CPU. Medido en OPPO CPH2557 (Mali-G57 MC2, 1.5B):
/// Vulkan decode 2.52 vs CPU 4.17 tok/s → disponible pero NO recomendado.
/// El planner dice "Vulkan soportado pero más lento que CPU" en vez de
/// "Vulkan soportado".
#[derive(Debug, Clone)]
pub struct BackendProfile {
    pub backend: Backend,
    pub available: bool,
    pub recommended: bool,
    /// Decode medido en este device (tok/s). None = no medido.
    pub measured_decode_tok_s: Option<f64>,
    /// Prefill medido en este device (tok/s). None = no medido.
    pub measured_prefill_tok_s: Option<f64>,
    pub confidence: ProfileConfidence,
    pub reason: String,
}

/// Origen del dato de rendimiento del perfil.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ProfileConfidence {
    /// Medido en este dispositivo exacto (benchmark real).
    Measured,
    /// Estimado por heurística (tamaño de modelo / familia de GPU).
    Heuristic,
    /// Sin dato disponible.
    Unknown,
}

/// Decisión única de ejecución — el planner es la autoridad; Flutter no decide.
/// Combina viabilidad (cabe / vale la pena) + backend recomendado + config
/// recomendada. La UI solo traduce esto a RECOMENDADO/BALANCED/LENTO/EXPERIMENTAL.
#[derive(Debug, Clone)]
pub struct ExecutionDecision {
    pub model_id: String,
    pub backend: Backend,
    pub viability: Viability,
    pub can_run: bool,
    pub should_run_interactive: bool,
    pub predicted_decode_tok_s: f64,
    pub threads: usize,
    pub context_size: usize,
    pub batch_size: usize,
    pub reason: String,
}

/// Risk level of the resulting plan.
#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord)]
pub enum RiskLevel {
    Low,
    Medium,
    High,
    Critical,
}

impl fmt::Display for RiskLevel {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            RiskLevel::Low => write!(f, "Low"),
            RiskLevel::Medium => write!(f, "Medium"),
            RiskLevel::High => write!(f, "High"),
            RiskLevel::Critical => write!(f, "Critical"),
        }
    }
}

/// Model sub-plan: which model + quant + context.
#[derive(Debug, Clone)]
pub struct ModelPlan {
    pub label: String,
    pub params_b: f32,
    pub quant: QuantLevel,
    pub model_size_mb: u64,
    pub context_tokens: usize,
}

/// Memory sub-plan: residency + KV + budget.
#[derive(Debug, Clone)]
pub struct MemoryPlan {
    pub kv_compression: KvCompression,
    pub page_strategy: PageStrategy,
    /// Streaming window (0 = disabled, whole model resident).
    pub streaming_window: usize,
    /// Ventana residente W: cuÃ¡ntas capas se mantienen en RAM. 0 = aÃºn sin
    /// determinar (se fija al cargar segÃºn el modelo real).
    pub resident_window: usize,
    /// Actual memory budget allotted to this plan (MB).
    pub budget_mb: u64,
}

/// Compute sub-plan: threads, cores, backend, speculative decoding.
#[derive(Debug, Clone)]
pub struct ComputePlan {
    pub threads: usize,
    /// Pin to big cores only (big.LITTLE).
    pub big_cores_only: bool,
    pub backend: Backend,
    pub speculative_decoding: bool,
}

/// Full plan produced by the planner.
#[derive(Debug, Clone)]
pub struct RuntimePlan {
    pub model: ModelPlan,
    pub memory: MemoryPlan,
    pub compute: ComputePlan,
    pub estimated_rss_mb: f64,
    pub risk: RiskLevel,
    /// Human-readable decision summary.
    pub summary: String,
}

impl fmt::Display for RuntimePlan {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{}", self.summary)
    }
}

// â”€â”€ OBSERVE input â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

/// Live resource observations fed into the planner.
#[derive(Debug, Clone)]
pub struct Observations {
    pub device: DeviceProfile,
    pub runtime: RuntimeMetrics,
    pub thermal: ThermalCondition,
    pub battery: BatteryMode,
    pub thrashing: ThrashingState,
}

impl Observations {
    /// Sample REAL signals from the OS. This is the OBSERVE step.
    ///
    /// Pulls from live components: hardware profile (RAM/SSD/CPU/thermal via
    /// `/proc`/`/sys`), runtime metrics (RSS/PSS/faults/PSI), thermal
    /// controller, battery guardian and thrashing detector. On Android/Linux
    /// these produce real numbers; on Windows the fault/PSI signals are
    /// structurally zero (no `/proc`).
    pub fn sample() -> Self {
        let device = profile_device();

        let mut collector = RuntimeMetricsCollector::new();
        let runtime = collector.collect();

        let mut thermal = ThermalController::new();
        let thermal_state = thermal.sample().state;

        let battery = BatteryGuardian::new().determine_mode();

        let mut ws = WorkingSetEstimator::new();
        let thrashing = ws.detect_thrashing().state;

        Observations {
            device,
            runtime,
            thermal: thermal_state,
            battery,
            thrashing,
        }
    }
}

// â”€â”€ MEASURE feedback â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

/// Measured results from an executed plan â€” the MEASURE step.
#[derive(Debug, Clone)]
pub struct Measurements {
    /// Measured tokens per second.
    pub tok_s: f64,
    /// Time to first token (ms).
    pub ttft_ms: f64,
    /// Measured quality (0.0â€“1.0) â€” confidence/perplexity proxy.
    pub quality: f32,
    /// Major page faults per second after generation (thrashing signal).
    pub fault_rate: f64,
    /// Thermal condition observed after generation.
    pub thermal: ThermalCondition,
}

// â”€â”€ Viabilidad (CanRun vs ShouldRun) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

/// Tier de viabilidad de una combinaciÃ³n modelo+dispositivo.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Viability {
    /// model << RAM: residente, rÃ¡pido.
    Fast,
    /// model â‰ˆ RAM: residencia adaptativa.
    Balanced,
    /// model > RAM: layer streaming, lento pero viable.
    Streaming,
    /// model >> RAM: thrashing extremo, no interactivo.
    Extreme,
}

impl fmt::Display for Viability {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Viability::Fast => write!(f, "FAST"),
            Viability::Balanced => write!(f, "BALANCED"),
            Viability::Streaming => write!(f, "STREAMING"),
            Viability::Extreme => write!(f, "EXTREME"),
        }
    }
}

/// Verdicto de viabilidad: distingue `can_run` (liveness) de
/// `should_run_interactive` (utilidad práctica).
#[derive(Debug, Clone)]
pub struct ViabilityReport {
    pub can_run: bool,
    pub should_run_interactive: bool,
    pub viability: Viability,
    pub reason: String,
    /// Predicción de decode en CPU (tok/s), heurística calibrada con medición
    /// real. 0.0 = no estimado (backend acelerado lo sobreescribe).
    pub predicted_decode_tok_s: f64,
}

/// Constante de calibración CPU: tok/s × tamaño_mb ≈ constante.
/// Medido en OPPO CPH2557 (arm64, 4 threads):
///   1.5B (1065 MB) → 4.2 tok/s → 4.2 × 1065 ≈ 4470
///   9B  (5512 MB) → 0.31 tok/s (con throttling; en frío ~0.7)
/// Se usa 4000 como punto medio conservador.
const CPU_DECODE_CALIBRATION: f64 = 4000.0;

/// Umbral de interactividad: por debajo de 1 tok/s la conversación no es
/// usable (cada token tarda >1s). El planner marca no-interactivo.
const INTERACTIVE_MIN_TOK_S: f64 = 1.0;

// â”€â”€ The planner â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

/// Runtime Planner â€” decides Memory/Compute/Model from a budget.
#[derive(Clone)]
pub struct RuntimePlanner {
    catalog: Vec<ModelCandidate>,
    model: MemoryModel,
    benchmark_store: Arc<Mutex<BenchmarkStore>>,
}

impl RuntimePlanner {
    /// Create a planner with the default model catalog.
    pub fn new() -> Self {
        Self {
            catalog: Self::default_catalog(),
            model: MemoryModel::default(),
            benchmark_store: Arc::new(Mutex::new(BenchmarkStore::in_memory())),
        }
    }

    /// Crea un planner con benchmark store persistente inyectado.
    pub fn with_benchmark_store(benchmark_store: BenchmarkStore) -> Self {
        Self {
            catalog: Self::default_catalog(),
            model: MemoryModel::default(),
            benchmark_store: Arc::new(Mutex::new(benchmark_store)),
        }
    }

    /// Default catalog â€” small, realistic candidates.
    fn default_catalog() -> Vec<ModelCandidate> {
        vec![
            ModelCandidate {
                label: "1.5B".into(),
                params_b: 1.5,
                size_mb: 1065,
                n_layers: 28,
                quant: QuantLevel::Q4,
            },
            ModelCandidate {
                label: "3B".into(),
                params_b: 3.0,
                size_mb: 2100,
                n_layers: 36,
                quant: QuantLevel::Q4,
            },
            ModelCandidate {
                label: "7B".into(),
                params_b: 7.0,
                size_mb: 4470,
                n_layers: 32,
                quant: QuantLevel::Q4,
            },
        ]
    }

    /// PLAN step: map a budget + live observations into a concrete plan.
    ///
    /// Decision cascade:
    /// 1. Effective memory ceiling = min(budget, available RAM), tightened by
    ///    battery / thermal / thrashing.
    /// 2. Target context from latency class, tightened by battery + thermal.
    /// 3. Pick the largest model that fits the ceiling (degrading context then
    ///    KV before downgrading the model).
    /// 4. Derive page strategy, streaming, compute (threads/cores/backend).
    pub fn plan(&self, budget: &InferenceBudget, obs: &Observations) -> RuntimePlan {
        let device = &obs.device;

        // 1. Effective ceiling. Prefer LIVE available RAM (from RuntimeMetrics)
        //    over the boot-time DeviceProfile value.
        let live_available_mb = obs.runtime.memory.available_bytes / 1_048_576;
        let avail_mb = if live_available_mb > 0 {
            live_available_mb
        } else {
            device.ram_available_mb
        };
        let mut ceiling = (budget.max_memory_mb.min(avail_mb) as f64).max(64.0);
        ceiling *= Self::battery_memory_factor(obs.battery);
        ceiling *= Self::thermal_memory_factor(obs.thermal);
        if obs.thrashing.is_thrashing() {
            ceiling *= 0.70;
        }

        // 2. Target context.
        let mut target_ctx = match budget.latency {
            LatencyClass::Interactive => 4096,
            LatencyClass::Batch => 8192,
            LatencyClass::Background => 2048,
        };
        target_ctx = Self::battery_context_limit(obs.battery, target_ctx);
        target_ctx = Self::thermal_context_limit(obs.thermal, target_ctx);

        // 3. Model + context + KV selection.
        let mut sorted = self.catalog.clone();
        sorted.sort_by(|a, b| b.params_b.total_cmp(&a.params_b));

        let mut chosen: Option<(ModelCandidate, usize, KvCompression, f64)> = None;
        for cand in &sorted {
            if let Some((ctx, kv, rss)) = self.fit(cand, ceiling, target_ctx) {
                chosen = Some((cand.clone(), ctx, kv, rss));
                break;
            }
        }

        // Fallback: survival â€” smallest model, minimal context, max compression.
        let (cand, ctx, kv, rss, streaming) = match chosen {
            Some((c, ctx, kv, rss)) => (c, ctx, kv, rss, 0usize),
            None => self.survival_fit(ceiling),
        };

        // 4. Risk + page strategy.
        let risk = Self::classify_risk(rss, device);
        let page = match risk {
            RiskLevel::Critical => PageStrategy::Conservative,
            RiskLevel::High => PageStrategy::Balanced,
            _ => PageStrategy::Aggressive,
        };

        // 5. Compute plan.
        let compute = self.compute_plan(device, budget, obs, risk);

        let summary = format!(
            "{} {} Â· ctx={} Â· KV={:?} Â· streaming={} Â· {} thread(s){}{} Â· backend={} Â· rss={:.0}MB (ceiling {:.0}) Â· risk={}",
            cand.label,
            cand.quant,
            ctx,
            kv,
            streaming,
            compute.threads,
            if compute.big_cores_only { " big-only" } else { "" },
            if compute.speculative_decoding { " Â· speculative" } else { "" },
            compute.backend,
            rss,
            ceiling,
            risk,
        );

        RuntimePlan {
            model: ModelPlan {
                label: cand.label,
                params_b: cand.params_b,
                quant: cand.quant,
                model_size_mb: cand.size_mb,
                context_tokens: ctx,
            },
            memory: MemoryPlan {
                kv_compression: kv,
                page_strategy: page,
                streaming_window: streaming,
                resident_window: if streaming > 0 {
                    streaming
                } else {
                    cand.n_layers
                },
                budget_mb: ceiling as u64,
            },
            compute,
            estimated_rss_mb: rss,
            risk,
            summary,
        }
    }

    /// ADAPT step: re-plan from measured results of the previous plan.
    ///
    /// Uses the measurements to tighten/loosen the effective budget, then
    /// re-runs the plan. Returns a plan plus a transition reason in `summary`.
    pub fn adapt(
        &self,
        budget: &InferenceBudget,
        obs: &Observations,
        prev: &RuntimePlan,
        meas: &Measurements,
    ) -> RuntimePlan {
        let mut adj = budget.clone();

        let mut reason = String::new();

        // Thrashing: the working set does not fit â€” tighten the ceiling.
        if meas.fault_rate > 100.0 {
            adj.max_memory_mb = ((budget.max_memory_mb as f64) * 0.70) as u64;
            reason.push_str(&format!(
                "thrashing(fault_rate={:.1}/s)â†’ceilingâ†“{:.0}%",
                meas.fault_rate, 30.0
            ));
        }

        // Quality shortfall with headroom: the budget is binding. We cannot
        // exceed the budget (it's a hard contract), so flag it honestly.
        if meas.quality < budget.min_quality && meas.fault_rate < 30.0 {
            if !reason.is_empty() {
                reason.push_str("; ");
            }
            reason.push_str(&format!(
                "quality={:.2}<min={:.2} (budget binding â€” no upgrade within {}MB)",
                meas.quality, budget.min_quality, budget.max_memory_mb
            ));
        }

        // Thermal spike: pin to fewer threads â€” handled by compute_plan via
        // fresh obs.thermal; record the trigger.
        if meas.thermal >= ThermalCondition::Hot {
            if !reason.is_empty() {
                reason.push_str("; ");
            }
            reason.push_str(&format!("thermal={:?}", meas.thermal));
        }

        let mut plan = self.plan(&adj, obs);

        // Avoid pointless oscillation: if nothing changed, keep the previous plan.
        if plan.model.label == prev.model.label
            && plan.model.context_tokens == prev.model.context_tokens
            && plan.memory.kv_compression == prev.memory.kv_compression
            && plan.compute.threads == prev.compute.threads
        {
            return prev.clone();
        }

        plan.summary = format!("[adapt: {}] {}", reason, plan.summary);
        plan
    }

    /// Clasifica la viabilidad de un modelo+dispositivo SIN cargar el modelo.
    ///
    /// Distingue `can_run` (liveness alcanzable) de `should_run_interactive`
    /// (generaci?n ?til). Un modelo >> RAM "can_run" (0.02 tok/s) pero NO
    /// "should_run_interactive" ? la app lo usa para advertir o recomendar
    /// un modelo menor en vez de arrancar algo inusable.
    pub fn assess_viability(&self, model_size_mb: u64, device: &DeviceProfile) -> ViabilityReport {
        let avail_mb = device.ram_available_mb.max(1) as f64;
        let ratio = model_size_mb as f64 / avail_mb;

        // Predicci?n de decode en CPU (heur?stica calibrada con medici?n real).
        let predicted_decode = CPU_DECODE_CALIBRATION / model_size_mb.max(1) as f64;

        let (viability, interactive, reason) = if ratio <= 0.7 {
            (
                Viability::Fast,
                true,
                "modelo cabe c?modamente en RAM".to_string(),
            )
        } else if ratio <= 1.0 {
            (
                Viability::Balanced,
                true,
                "modelo ? RAM disponible: residencia adaptativa".to_string(),
            )
        } else if ratio <= 2.0 {
            (
                Viability::Streaming,
                true,
                "modelo > RAM: layer streaming (lento pero viable)".to_string(),
            )
        } else {
            (
                Viability::Extreme,
                false,
                "modelo >> RAM: thrashing extremo, generaci?n no interactiva".to_string(),
            )
        };

        // Endurecimiento CPU: aunque "cabe" (streaming), un decode < 1 tok/s
        // no es una experiencia interactiva. El planner distingue "vale la
        // pena ejecutarlo as?" de "solo cabe" ? memory liveness y interactive
        // performance son objetivos distintos (medido en OPPO: 9B = 0.31 tok/s).
        let should_run_interactive = interactive && predicted_decode >= INTERACTIVE_MIN_TOK_S;
        let reason = if interactive && !should_run_interactive {
            format!(
                "{}; decode CPU estimado {:.2} tok/s < 1.0 ? no interactivo, requiere GPU/NPU",
                reason, predicted_decode
            )
        } else {
            reason
        };

        ViabilityReport {
            can_run: true,
            should_run_interactive,
            viability,
            reason,
            predicted_decode_tok_s: predicted_decode,
        }
    }

    /// Perfil de backend para este dispositivo, resolviendo mediciones
    /// persistidas cuando existen.
    pub fn backend_profile(
        &self,
        backend: Backend,
        device: &DeviceProfile,
        model: &ModelFingerprint,
    ) -> BackendProfile {
        let device_fp = DeviceFingerprint::from_device(device);
        let resolved = self
            .benchmark_store
            .lock()
            .ok()
            .and_then(|store| store.resolve(&device_fp, model, backend.as_str()));
        match backend {
            Backend::Cpu => BackendProfile {
                backend,
                available: true,
                recommended: true,
                measured_decode_tok_s: resolved.as_ref().map(|(p, _)| p.decode_sustained_tok_s),
                measured_prefill_tok_s: resolved.as_ref().map(|(p, _)| p.prefill_tok_s),
                confidence: match resolved.as_ref().map(|(_, level)| level) {
                    Some(ResolutionLevel::Exact) | Some(ResolutionLevel::SameTier) => {
                        ProfileConfidence::Measured
                    }
                    None => ProfileConfidence::Heuristic,
                },
                reason: match resolved {
                    Some((_, ResolutionLevel::Exact)) => {
                        "CPU baseline medido en este dispositivo".to_string()
                    }
                    Some((_, ResolutionLevel::SameTier)) => {
                        "CPU baseline reutilizado desde el mismo tier".to_string()
                    }
                    None => "CPU baseline no medido; cae a heur?stica".to_string(),
                },
            },
            Backend::Vulkan => BackendProfile {
                backend,
                available: true,
                // Medido m?s lento que CPU en Mali-G57 MC2 (matrix cores: none).
                // En Adreno/Mali alto el resultado puede invertirse ? re-medir.
                recommended: false,
                measured_decode_tok_s: resolved.as_ref().map(|(p, _)| p.decode_sustained_tok_s),
                measured_prefill_tok_s: resolved.as_ref().map(|(p, _)| p.prefill_tok_s),
                confidence: match resolved.as_ref().map(|(_, level)| level) {
                    Some(ResolutionLevel::Exact) | Some(ResolutionLevel::SameTier) => {
                        ProfileConfidence::Measured
                    }
                    None => ProfileConfidence::Heuristic,
                },
                reason: match resolved {
                    Some((_, ResolutionLevel::Exact)) => {
                        "Vulkan medido en este dispositivo".to_string()
                    }
                    Some((_, ResolutionLevel::SameTier)) => {
                        "Vulkan reutilizado desde el mismo tier".to_string()
                    }
                    None => "Vulkan disponible pero sin medici?n persistida".to_string(),
                },
            },
            Backend::Npu => BackendProfile {
                backend,
                available: false,
                recommended: false,
                measured_decode_tok_s: None,
                measured_prefill_tok_s: None,
                confidence: ProfileConfidence::Unknown,
                reason: "NPU no detectado en este dispositivo".to_string(),
            },
        }
    }

    /// Devuelve el perfil medido que debe gobernar una carga concreta.
    ///
    /// La selección (exacto -> mismo tier) vive aquí, junto al planner: el
    /// caller no debe volver a implementar matching de fingerprints. El
    /// perfil incluye los parámetros de carga ganadores (threads/context/batch)
    /// además de las métricas que usa `backend_profile` para explicar la
    /// decisión.
    pub fn measured_profile(
        &self,
        backend: Backend,
        device: &DeviceProfile,
        model: &ModelFingerprint,
    ) -> Option<(MeasuredExecutionProfile, ResolutionLevel)> {
        self.benchmark_store.lock().ok().and_then(|store| {
            store.resolve(
                &DeviceFingerprint::from_device(device),
                model,
                backend.as_str(),
            )
        })
    }

    /// Guarda atómicamente un perfil ya validado por el runtime. Compartir el
    /// store entre clones del planner permite que una medición se use sin
    /// reiniciar el proceso ni recrear ModelManager.
    pub fn persist_measured_profile(
        &self,
        profile: MeasuredExecutionProfile,
    ) -> std::io::Result<()> {
        let mut store = self.benchmark_store.lock().map_err(|_| {
            std::io::Error::new(std::io::ErrorKind::Other, "benchmark store lock poisoned")
        })?;
        store.upsert(profile);
        store.save()
    }

    /// Decisión de ejecución para un modelo+backend. Combina la viabilidad
    /// (assess_viability) con el perfil del backend (backend_profile) y una
    /// config recomendada. Si el backend no está recomendado, se degrada a CPU.
    pub fn execution_decision(
        &self,
        model_id: &str,
        model_size_mb: u64,
        backend: Backend,
        device: &DeviceProfile,
        model: &ModelFingerprint,
    ) -> ExecutionDecision {
        let v = self.assess_viability(model_size_mb, device);
        let bp = self.backend_profile(backend, device, model);
        let cpu_profile = self.backend_profile(Backend::Cpu, device, model);

        // Si el backend pedido no está recomendado, degradar a CPU (siempre lo está).
        let effective_backend = if bp.recommended {
            backend
        } else {
            Backend::Cpu
        };
        let predicted = if effective_backend == Backend::Cpu {
            cpu_profile
                .measured_decode_tok_s
                .unwrap_or(v.predicted_decode_tok_s)
        } else {
            bp.measured_decode_tok_s.unwrap_or(v.predicted_decode_tok_s)
        };
        let reason = if !bp.recommended && backend != Backend::Cpu {
            format!("{}; usando CPU: {}", v.reason, bp.reason)
        } else {
            v.reason.clone()
        };

        ExecutionDecision {
            model_id: model_id.to_string(),
            backend: effective_backend,
            viability: v.viability,
            can_run: v.can_run,
            should_run_interactive: v.should_run_interactive,
            predicted_decode_tok_s: predicted,
            threads: 4,
            context_size: 4096,
            batch_size: 256,
            reason,
        }
    }

    /// Planifica para UN modelo especÃ­fico (tamaÃ±o conocido, no el catÃ¡logo).
    ///
    /// Lo usa `load_model` para decidir la configuraciÃ³n aplicada (contexto,
    /// threads, ventana residente W). Reemplaza al `ExecutionPlanner` legacy
    /// (`auto_configure_v2`): misma lÃ³gica de ceiling/fit, pero con seÃ±ales
    /// reales del OS y un Ãºnico planner como fuente de verdad.
    #[allow(clippy::too_many_arguments)]
    pub fn plan_for_model(
        &self,
        model_size_mb: u64,
        n_layers: usize,
        target_context: usize,
        budget: &InferenceBudget,
        obs: &Observations,
    ) -> RuntimePlan {
        let device = &obs.device;
        let n_layers = n_layers.max(1);

        // Ceiling efectivo (mismo que plan()).
        let live_available_mb = obs.runtime.memory.available_bytes / 1_048_576;
        let avail_mb = if live_available_mb > 0 {
            live_available_mb
        } else {
            device.ram_available_mb
        };
        let mut ceiling = (budget.max_memory_mb.min(avail_mb) as f64).max(64.0);
        ceiling *= Self::battery_memory_factor(obs.battery);
        ceiling *= Self::thermal_memory_factor(obs.thermal);
        if obs.thrashing.is_thrashing() {
            ceiling *= 0.70;
        }

        let target_ctx = Self::battery_context_limit(obs.battery, target_context);
        let target_ctx = Self::thermal_context_limit(obs.thermal, target_ctx);

        let cand = ModelCandidate {
            label: format!("{}MB", model_size_mb),
            params_b: 0.0,
            size_mb: model_size_mb,
            n_layers,
            quant: QuantLevel::Q4,
        };

        let (ctx, kv, rss, streaming) = match self.fit(&cand, ceiling, target_ctx) {
            Some((ctx, kv, rss)) => (ctx, kv, rss, 0usize),
            None => {
                let (_, ctx, kv, rss, streaming) = self.survival_fit(ceiling);
                (ctx, kv, rss, streaming)
            }
        };

        // Ventana residente W: capas que caben en el presupuesto (mÃ­n 4).
        let bytes_per_layer = model_size_mb as f64 / n_layers as f64;
        let window = (ceiling / bytes_per_layer.max(1.0))
            .max(4.0)
            .min(n_layers as f64) as usize;

        let risk = Self::classify_risk(rss, device);
        let page = match risk {
            RiskLevel::Critical => PageStrategy::Conservative,
            RiskLevel::High => PageStrategy::Balanced,
            _ => PageStrategy::Aggressive,
        };
        let compute = self.compute_plan(device, budget, obs, risk);

        let summary = format!(
            "{} Q4 Â· ctx={} Â· KV={:?} Â· W={} Â· {} thread(s) Â· backend={} Â· rss={:.0}MB (ceiling {:.0}) Â· risk={}",
            cand.label,
            ctx,
            kv,
            window,
            compute.threads,
            compute.backend,
            rss,
            ceiling,
            risk,
        );

        RuntimePlan {
            model: ModelPlan {
                label: cand.label,
                params_b: 0.0,
                quant: QuantLevel::Q4,
                model_size_mb,
                context_tokens: ctx,
            },
            memory: MemoryPlan {
                kv_compression: kv,
                page_strategy: page,
                streaming_window: streaming,
                resident_window: window,
                budget_mb: ceiling as u64,
            },
            compute,
            estimated_rss_mb: rss,
            risk,
            summary,
        }
    }

    /// Try to fit a candidate within the ceiling: prefer the largest context
    /// that fits, degrading KV before context, then halving context.
    fn fit(
        &self,
        cand: &ModelCandidate,
        ceiling_mb: f64,
        target_ctx: usize,
    ) -> Option<(usize, KvCompression, f64)> {
        let ctx_ladder = Self::context_ladder(target_ctx);
        let kv_ladder = [
            KvCompression::None,
            KvCompression::Int8,
            KvCompression::Int4,
            KvCompression::Int2,
        ];

        for &ctx in &ctx_ladder {
            for &kv in &kv_ladder {
                let est = self
                    .model
                    .estimate_rss(cand.size_mb as f64, ctx, cand.n_layers, kv);
                if est.peak_rss_mb <= ceiling_mb {
                    return Some((ctx, kv, est.peak_rss_mb));
                }
            }
        }
        None
    }

    /// Last resort: smallest model, minimal context, max KV compression,
    /// with layer streaming if the model still does not fit.
    fn survival_fit(&self, ceiling_mb: f64) -> (ModelCandidate, usize, KvCompression, f64, usize) {
        let cand = self
            .catalog
            .iter()
            .min_by(|a, b| a.size_mb.cmp(&b.size_mb))
            .cloned()
            .unwrap_or_else(|| ModelCandidate {
                label: "1.5B".into(),
                params_b: 1.5,
                size_mb: 1065,
                n_layers: 28,
                quant: QuantLevel::Q4,
            });

        let ctx = 256;
        let kv = KvCompression::Int2;

        let direct = self
            .model
            .estimate_rss(cand.size_mb as f64, ctx, cand.n_layers, kv);
        if direct.peak_rss_mb <= ceiling_mb {
            return (cand, ctx, kv, direct.peak_rss_mb, 0);
        }

        // Streaming: 2-layer window keeps VMA tiny. Only viable if the model
        // is actually bigger than the ceiling.
        let bytes_per_layer = cand.size_mb as f64 / cand.n_layers.max(1) as f64;
        let vma = self
            .model
            .estimate_streaming_vma(2, bytes_per_layer, cand.n_layers);
        (cand, ctx, kv, vma.min(direct.peak_rss_mb), 2)
    }

    /// Compute plan: threads/cores/backend from thermal, battery and device.
    fn compute_plan(
        &self,
        device: &DeviceProfile,
        budget: &InferenceBudget,
        obs: &Observations,
        risk: RiskLevel,
    ) -> ComputePlan {
        let big = if device.big_cores > 0 {
            device.big_cores
        } else {
            (device.cpu_cores / 2).max(2)
        };

        let threads = match (obs.thermal, obs.battery) {
            (ThermalCondition::Critical, _) => 1,
            (ThermalCondition::Hot, _) => 2,
            (_, BatteryMode::Survival) => 1,
            (_, BatteryMode::Eco) => 2,
            _ => match device.tier {
                // Desktop/Flagship: todos los cores (homogÃ©neos o suficientes).
                DeviceTier::Desktop | DeviceTier::Flagship => device.cpu_cores.max(1) as usize,
                // Mobile: solo big cores (evitar thrashing LITTLE).
                _ => big.max(1) as usize,
            },
        };

        let big_cores_only =
            obs.battery == BatteryMode::Eco || obs.battery == BatteryMode::Survival;

        // On-device backend only (cloud routing is the orchestrator's job, not
        // this planner). NPU if present, Vulkan on flagship, else CPU.
        let backend = if device.npu_available {
            Backend::Npu
        } else if device.tier >= DeviceTier::Flagship {
            Backend::Vulkan
        } else {
            Backend::Cpu
        };

        // Speculative decoding only helps interactive latency on capable,
        // cool, plugged-in devices â€” not worth the RAM otherwise.
        let speculative = budget.latency == LatencyClass::Interactive
            && matches!(obs.battery, BatteryMode::Performance)
            && obs.thermal < ThermalCondition::Hot
            && risk <= RiskLevel::Medium;

        ComputePlan {
            threads,
            big_cores_only,
            backend,
            speculative_decoding: speculative,
        }
    }

    // â”€â”€ Helpers â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

    fn context_ladder(target: usize) -> Vec<usize> {
        let mut out = Vec::new();
        let mut ctx = target;
        while ctx >= 256 {
            if out.last() != Some(&ctx) {
                out.push(ctx);
            }
            ctx /= 2;
        }
        if out.last() != Some(&256) {
            out.push(256);
        }
        out
    }

    fn battery_memory_factor(mode: BatteryMode) -> f64 {
        match mode {
            BatteryMode::Performance => 1.0,
            BatteryMode::Balanced => 0.90,
            BatteryMode::Eco => 0.75,
            BatteryMode::Survival => 0.55,
        }
    }

    fn thermal_memory_factor(thermal: ThermalCondition) -> f64 {
        match thermal {
            ThermalCondition::Cool => 1.0,
            ThermalCondition::Warm => 0.90,
            ThermalCondition::Hot => 0.70,
            ThermalCondition::Critical => 0.50,
        }
    }

    fn battery_context_limit(mode: BatteryMode, ctx: usize) -> usize {
        match mode {
            BatteryMode::Performance => ctx,
            BatteryMode::Balanced => ctx.min(4096),
            BatteryMode::Eco => ctx.min(1024),
            BatteryMode::Survival => 256,
        }
    }

    fn thermal_context_limit(thermal: ThermalCondition, ctx: usize) -> usize {
        match thermal {
            ThermalCondition::Cool | ThermalCondition::Warm => ctx,
            ThermalCondition::Hot => (ctx / 2).max(256),
            ThermalCondition::Critical => 256,
        }
    }

    fn classify_risk(rss_mb: f64, device: &DeviceProfile) -> RiskLevel {
        let total = device.ram_total_mb.max(1) as f64;
        let avail = device.ram_available_mb.max(1) as f64;
        let ratio_total = rss_mb / total;
        let ratio_avail = rss_mb / avail;

        if ratio_avail > 1.0 || ratio_total > 0.90 {
            RiskLevel::Critical
        } else if ratio_total > 0.75 || ratio_avail > 0.85 {
            RiskLevel::High
        } else if ratio_avail > 0.70 {
            RiskLevel::Medium
        } else {
            RiskLevel::Low
        }
    }
}

impl Default for RuntimePlanner {
    fn default() -> Self {
        Self::new()
    }
}

// â”€â”€ Tests â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

#[cfg(test)]
mod tests {
    use super::*;
    use crate::memory_engine::{MeasuredExecutionProfile, BENCHMARK_SCHEMA_VERSION};

    fn samsung() -> DeviceProfile {
        DeviceProfile {
            ram_total_mb: 3814,
            ram_available_mb: 1900,
            storage_read_mbps: 364,
            storage_write_mbps: 200,
            cpu_cores: 8,
            big_cores: 2,
            cpu_temp_c: 42,
            zram_active: true,
            npu_available: false,
            tier: DeviceTier::Budget,
            oom_score: 180,
            oom_score_adj: 0,
        }
    }

    fn oppo() -> DeviceProfile {
        DeviceProfile {
            ram_total_mb: 7823,
            ram_available_mb: 3900,
            storage_read_mbps: 1067,
            storage_write_mbps: 800,
            cpu_cores: 8,
            big_cores: 4,
            cpu_temp_c: 38,
            zram_active: true,
            npu_available: false,
            tier: DeviceTier::MidRange,
            oom_score: 85,
            oom_score_adj: 0,
        }
    }

    fn obs(
        device: DeviceProfile,
        thermal: ThermalCondition,
        battery: BatteryMode,
        thrashing: ThrashingState,
    ) -> Observations {
        let runtime = RuntimeMetricsCollector::new().collect();
        Observations {
            device,
            runtime,
            thermal,
            battery,
            thrashing,
        }
    }

    fn interactive_budget(memory_mb: u64) -> InferenceBudget {
        InferenceBudget {
            max_memory_mb: memory_mb,
            ..InferenceBudget::default()
        }
    }

    #[test]
    fn test_constrained_budget_picks_small_model() {
        let planner = RuntimePlanner::new();
        // Samsung with only 1.5 GB ceiling â†’ 7B/3B won't fit, must pick 1.5B.
        let plan = planner.plan(
            &interactive_budget(1500),
            &obs(
                samsung(),
                ThermalCondition::Cool,
                BatteryMode::Performance,
                ThrashingState::None,
            ),
        );
        assert_eq!(plan.model.label, "1.5B");
        assert!(plan.estimated_rss_mb <= 1500.0);
    }

    #[test]
    fn test_roomy_budget_picks_7b() {
        let planner = RuntimePlanner::new();
        // OPPO with 6 GB ceiling â†’ 7B fits.
        let plan = planner.plan(
            &interactive_budget(6000),
            &obs(
                oppo(),
                ThermalCondition::Cool,
                BatteryMode::Performance,
                ThrashingState::None,
            ),
        );
        assert_eq!(plan.model.label, "7B");
        assert!(plan.estimated_rss_mb <= 6000.0);
    }

    #[test]
    fn test_plan_never_exceeds_budget() {
        let planner = RuntimePlanner::new();
        for budget_mb in [512u64, 1024, 1500, 2000, 3000, 4500, 6000] {
            let plan = planner.plan(
                &interactive_budget(budget_mb),
                &obs(
                    samsung(),
                    ThermalCondition::Cool,
                    BatteryMode::Performance,
                    ThrashingState::None,
                ),
            );
            assert!(
                plan.estimated_rss_mb <= budget_mb as f64 + 1.0,
                "budget {}MB exceeded: rss={} plan={}",
                budget_mb,
                plan.estimated_rss_mb,
                plan.summary
            );
        }
    }

    #[test]
    fn test_thermal_hot_reduces_compute() {
        let planner = RuntimePlanner::new();
        let cool = planner.plan(
            &interactive_budget(4000),
            &obs(
                oppo(),
                ThermalCondition::Cool,
                BatteryMode::Performance,
                ThrashingState::None,
            ),
        );
        let hot = planner.plan(
            &interactive_budget(4000),
            &obs(
                oppo(),
                ThermalCondition::Hot,
                BatteryMode::Performance,
                ThrashingState::None,
            ),
        );
        assert!(hot.compute.threads <= cool.compute.threads);
        assert!(hot.model.context_tokens <= cool.model.context_tokens);
    }

    #[test]
    fn test_battery_survival_degrades_aggressively() {
        let planner = RuntimePlanner::new();
        let plan = planner.plan(
            &interactive_budget(4000),
            &obs(
                oppo(),
                ThermalCondition::Cool,
                BatteryMode::Survival,
                ThrashingState::None,
            ),
        );
        assert_eq!(plan.compute.threads, 1);
        assert!(plan.compute.big_cores_only);
        assert_eq!(plan.model.context_tokens, 256);
    }

    #[test]
    fn test_adapt_thrashing_tightens_budget() {
        let planner = RuntimePlanner::new();
        let device = oppo();
        let budget = interactive_budget(6000);
        let o = obs(
            device.clone(),
            ThermalCondition::Cool,
            BatteryMode::Performance,
            ThrashingState::None,
        );
        let prev = planner.plan(&budget, &o);
        assert_eq!(prev.model.label, "7B");

        // Severe thrashing measured â†’ adapt must shrink the plan.
        let meas = Measurements {
            tok_s: 1.0,
            ttft_ms: 2000.0,
            quality: 0.85,
            fault_rate: 250.0,
            thermal: ThermalCondition::Warm,
        };
        let adapted = planner.adapt(&budget, &o, &prev, &meas);
        assert!(adapted.summary.contains("adapt"));
        // Either a smaller model or reduced context / more KV compression.
        let degraded = adapted.model.params_b < prev.model.params_b
            || adapted.model.context_tokens < prev.model.context_tokens
            || adapted.memory.kv_compression != KvCompression::None;
        assert!(degraded, "adapt did not degrade: {}", adapted.summary);
    }

    #[test]
    fn test_adapt_no_change_keeps_prev() {
        let planner = RuntimePlanner::new();
        let device = oppo();
        let budget = interactive_budget(6000);
        let o = obs(
            device.clone(),
            ThermalCondition::Cool,
            BatteryMode::Performance,
            ThrashingState::None,
        );
        let prev = planner.plan(&budget, &o);

        // Healthy measurements â†’ no change â†’ returns prev unchanged.
        let meas = Measurements {
            tok_s: 8.0,
            ttft_ms: 400.0,
            quality: 0.90,
            fault_rate: 2.0,
            thermal: ThermalCondition::Cool,
        };
        let adapted = planner.adapt(&budget, &o, &prev, &meas);
        assert_eq!(adapted.model.label, prev.model.label);
        assert_eq!(adapted.model.context_tokens, prev.model.context_tokens);
    }

    #[test]
    fn test_observations_sample_is_real() {
        // Exercises the OBSERVE step against real components. Must not panic.
        let o = Observations::sample();
        assert!(o.device.ram_total_mb > 0);
        assert!(o.runtime.memory.total_bytes > 0);
    }

    #[test]
    fn test_context_ladder_descending() {
        let l = RuntimePlanner::context_ladder(8192);
        assert_eq!(l, vec![8192, 4096, 2048, 1024, 512, 256]);
        let l2 = RuntimePlanner::context_ladder(1024);
        assert_eq!(l2, vec![1024, 512, 256]);
    }

    #[test]
    fn test_assess_viability_tiers() {
        let planner = RuntimePlanner::new();
        let d = oppo(); // ram_available_mb = 3900
        let r_15b = planner.assess_viability(1065, &d);
        assert_eq!(r_15b.viability, Viability::Fast);
        assert!(r_15b.should_run_interactive);
        let r_9b = planner.assess_viability(5512, &d);
        assert_eq!(r_9b.viability, Viability::Streaming);
        assert!(r_9b.can_run);
        // 9B en CPU ≈ 0.73 tok/s estimado (< 1.0) → no interactivo aunque
        // "cabe" por streaming. Medido real en OPPO: 0.31 tok/s.
        assert!(!r_9b.should_run_interactive);
        assert!(r_9b.reason.contains("no interactivo"));
        assert!(r_9b.predicted_decode_tok_s < 1.0);
        let r_27b = planner.assess_viability(18094, &d);
        assert_eq!(r_27b.viability, Viability::Extreme);
        assert!(r_27b.can_run);
        assert!(!r_27b.should_run_interactive);
        assert!(r_27b.reason.contains("thrashing"));
    }

    #[test]
    fn test_quant_display() {
        assert_eq!(QuantLevel::Q4.to_string(), "Q4_K_M");
        assert_eq!(QuantLevel::Q8.to_string(), "Q8_0");
    }

    fn benchmark_device() -> DeviceProfile {
        oppo()
    }

    fn benchmark_model() -> ModelFingerprint {
        ModelFingerprint {
            architecture: "qwen2".to_string(),
            parameter_count: 1_500_000_000,
            block_count: 28,
            file_size_bytes: 1_065 * 1024 * 1024,
        }
    }

    fn benchmark_planner() -> RuntimePlanner {
        let device = benchmark_device();
        let model = benchmark_model();
        let mut store = BenchmarkStore::in_memory();
        let fp = DeviceFingerprint::from_device(&device);
        store.upsert(MeasuredExecutionProfile {
            schema_version: BENCHMARK_SCHEMA_VERSION,
            device: fp.clone(),
            model: model.clone(),
            backend: "cpu".to_string(),
            threads: 4,
            context_tokens: 4096,
            batch_size: 256,
            ttft_ms: 400.0,
            prefill_tok_s: 20.0,
            decode_peak_tok_s: 4.17,
            decode_sustained_tok_s: 3.75,
            pss_peak_mb: 1500.0,
            major_faults_per_second: 2.0,
            temperature_start_c: 30.0,
            temperature_peak_c: 42.0,
            thermal_decay_pct: 0.1,
            samples: 50,
            measured_at: "2026-08-19T00:00:00Z".to_string(),
        });
        store.upsert(MeasuredExecutionProfile {
            schema_version: BENCHMARK_SCHEMA_VERSION,
            device: fp,
            model,
            backend: "vulkan".to_string(),
            threads: 4,
            context_tokens: 4096,
            batch_size: 256,
            ttft_ms: 480.0,
            prefill_tok_s: 16.0,
            decode_peak_tok_s: 2.52,
            decode_sustained_tok_s: 2.20,
            pss_peak_mb: 1600.0,
            major_faults_per_second: 3.0,
            temperature_start_c: 31.0,
            temperature_peak_c: 44.0,
            thermal_decay_pct: 0.12,
            samples: 50,
            measured_at: "2026-08-19T00:00:00Z".to_string(),
        });
        RuntimePlanner::with_benchmark_store(store)
    }

    #[test]
    fn test_backend_profile_measured() {
        let planner = benchmark_planner();
        let d = benchmark_device();
        let m = benchmark_model();

        let cpu = planner.backend_profile(Backend::Cpu, &d, &m);
        assert!(cpu.available);
        assert!(cpu.recommended);
        assert_eq!(cpu.confidence, ProfileConfidence::Measured);
        assert!((cpu.measured_decode_tok_s.unwrap() - 3.75).abs() < 0.001);

        let (stored, resolution) = planner
            .measured_profile(Backend::Cpu, &d, &m)
            .expect("el perfil CPU exacto debe estar disponible para la carga");
        assert_eq!(resolution, ResolutionLevel::Exact);
        assert_eq!(
            (stored.threads, stored.context_tokens, stored.batch_size),
            (4, 4096, 256)
        );

        let vulkan = planner.backend_profile(Backend::Vulkan, &d, &m);
        assert!(vulkan.available, "Vulkan est? disponible");
        assert!(
            !vulkan.recommended,
            "pero no recomendado (m?s lento que CPU)"
        );
        assert!((vulkan.measured_decode_tok_s.unwrap() - 2.20).abs() < 0.001);

        let npu = planner.backend_profile(Backend::Npu, &d, &m);
        assert!(!npu.available);
        assert_eq!(npu.confidence, ProfileConfidence::Unknown);
    }

    #[test]
    fn test_execution_decision_vulkan_degrades_to_cpu() {
        let planner = benchmark_planner();
        let d = benchmark_device();
        let m = benchmark_model();

        // 1.5B en Vulkan ? no recomendado (medido m?s lento) ? degrada a CPU.
        let dec = planner.execution_decision("qwen15", 1065, Backend::Vulkan, &d, &m);
        assert_eq!(dec.backend, Backend::Cpu, "Vulkan degrada a CPU en CPH2557");
        assert!(dec.can_run);
        assert!(dec.should_run_interactive);

        // 9B en CPU ? no interactivo (0.73 tok/s estimado).
        let dec9 = planner.execution_decision("qwen9", 5512, Backend::Cpu, &d, &m);
        assert_eq!(dec9.backend, Backend::Cpu);
        assert!(!dec9.should_run_interactive);
    }
}
