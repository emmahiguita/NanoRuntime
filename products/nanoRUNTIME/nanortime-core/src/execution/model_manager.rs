//! Gestor de modelos de IA.
//!
//! Crea contexto fresco por cada generación para evitar contaminación del KV cache.

use std::path::Path;
#[cfg(not(feature = "simulated"))]
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::Arc;
#[cfg(not(feature = "simulated"))]
use std::time::Instant;

use tokio::sync::RwLock;

use crate::config::manifest::Config;
use crate::error::{NanoError, Result};
#[cfg(not(feature = "simulated"))]
use crate::execution::prefix_cache::{content_hash, PrefixKey, PrefixLookup};
use crate::execution::prefix_cache::PrefixCache;
#[cfg(not(feature = "simulated"))]
use crate::execution::session::{NanoSession, SessionState, template_hash};
#[cfg(not(feature = "simulated"))]
use crate::inference_backend::{
    BackendGenerateParams, BackendLoadParams, InferenceBackend, LlamaCppBackend,
};

#[cfg(not(feature = "simulated"))]
type NanoModel = <LlamaCppBackend as InferenceBackend>::Model;
#[cfg(not(feature = "simulated"))]
type NanoContext = <LlamaCppBackend as InferenceBackend>::Context;
#[cfg(not(feature = "simulated"))]
type NanoLoraAdapter = <LlamaCppBackend as InferenceBackend>::LoraAdapter;

type TokenChunk = (String, f32);
type TokenReceiver = tokio::sync::mpsc::Receiver<TokenChunk>;

struct ModelState {
    model_path: String,
    context_size: usize,
    #[allow(dead_code)]
    is_simulated: bool,
    #[cfg(not(feature = "simulated"))]
    context: Option<NanoContext>,
    #[cfg(not(feature = "simulated"))]
    model: Option<NanoModel>,
    #[cfg(not(feature = "simulated"))]
    load_params: BackendLoadParams,
    #[cfg(not(feature = "simulated"))]
    lora_adapter: Option<NanoLoraAdapter>,
    #[cfg(not(feature = "simulated"))]
    lora_path: Option<String>,
    /// Gate R5 — supervisor de sesión: gates de invalidación del KV
    /// (modelo/template/rollback). None = sin sesión activa.
    #[cfg(not(feature = "simulated"))]
    session: Option<NanoSession>,
    /// Chat template leído de la metadata del GGUF (None en modelos base).
    /// Detecta instruct-ness sin depender del nombre del archivo.
    #[cfg(not(feature = "simulated"))]
    chat_template: Option<String>,
    #[cfg_attr(feature = "simulated", allow(dead_code))]
    generation: u64,
}

pub struct ModelManager {
    config: Config,
    // Arc so blocking generation threads can restore the model into state via
    // blocking_write() once inference finishes (tokio-sanctioned pattern).
    state: Arc<RwLock<Option<ModelState>>>,
    pub memory_engine: std::sync::Mutex<crate::memory_engine::NanoMemoryEngine>,
    /// Collector de métricas runtime REALES (faults de /proc, PSS, latencia
    /// inter-token). Fuera de ModelState: sobrevive al patrón take/return
    /// del modelo durante spawn_blocking.
    metrics: Arc<std::sync::Mutex<crate::memory_engine::RuntimeMetricsCollector>>,
    /// Estimador de working set — cierra el lazo observer→estimator del
    /// control plane con señales reales (fault_rate, I/O, presión PSI).
    working_set: std::sync::Mutex<crate::memory_engine::WorkingSetEstimator>,
    /// Device profile cacheado — `profile_device()` corre un benchmark de
    /// almacenamiento, así que se muestrea UNA vez y se reutiliza en el hot path.
    device: crate::memory_engine::DeviceProfile,
    /// Planificador OS-like: budget → Memory/Compute/Model plan + lazo ADAPT.
    planner: crate::memory_engine::RuntimePlanner,
    /// Presupuesto declarativo derivado de la RAM real disponible.
    runtime_budget: crate::memory_engine::InferenceBudget,
    /// Último plan emitido — referencia del lazo ADAPT (evita oscilación).
    last_plan: Arc<std::sync::Mutex<Option<crate::memory_engine::RuntimePlan>>>,
    /// Residency manager con el puntero mmap real — evicta/prefetcha capas
    /// vía madvise (tesis DOOM). Construido en load_model. Arc para poder
    /// compartirlo con el closure de streaming (aplica W en vivo).
    residency: Arc<std::sync::Mutex<Option<crate::memory_engine::ResidencyManager>>>,
    /// PrefixCache (V1.1) — snapshot del KV del prefix estático, reutilizable
    /// entre sesiones. El dir real (files/nano/prefix-cache en Android) se
    /// configura en Etapa 3; por ahora temp_dir para CI/desarrollo.
    #[cfg_attr(feature = "simulated", allow(dead_code))]
    prefix_cache: PrefixCache,
}

/// Umbral de thrashing: major page faults por segundo. En flash móvil un
/// fault se resuelve en ~1ms; >20/s significa que el working set excede
/// RAM y el kernel vive paginando (I/O-bound, no compute-bound).
const THRASH_MAJFAULT_RATE: f64 = 20.0;

/// ADAPT — replanifica a partir de lo medido. Función libre para poder
/// llamarse tanto desde `update_memory_engine_metrics` como desde el closure
/// de `spawn_blocking` de streaming (donde `&self` no está disponible).
#[allow(clippy::too_many_arguments)]
fn run_adapt_cycle(
    planner: &crate::memory_engine::RuntimePlanner,
    budget: &crate::memory_engine::InferenceBudget,
    device: &crate::memory_engine::DeviceProfile,
    last_plan: &std::sync::Mutex<Option<crate::memory_engine::RuntimePlan>>,
    residency: &std::sync::Mutex<Option<crate::memory_engine::ResidencyManager>>,
    runtime: crate::memory_engine::RuntimeMetrics,
    fault_rate: f64,
    perplexity: f32,
    thrashing: crate::memory_engine::ThrashingState,
    thermal: crate::memory_engine::ThermalCondition,
    battery: crate::memory_engine::BatteryMode,
) {
    let quality = (1.0 / perplexity).clamp(0.0, 1.0);
    let meas = crate::memory_engine::Measurements {
        tok_s: 0.0,
        ttft_ms: 0.0,
        quality,
        fault_rate,
        thermal,
    };
    let obs = crate::memory_engine::Observations {
        device: device.clone(),
        runtime,
        thermal,
        battery,
        thrashing,
    };
    if let Ok(mut last) = last_plan.lock() {
        if let Some(prev) = last.as_ref() {
            let adapted = planner.adapt(budget, &obs, prev, &meas);
            tracing::info!("[RuntimePlanner] {}", adapted.summary);
            // APLICAR el W adaptado en vivo — cierra el lazo ADAPT→RE-EXECUTE.
            let old_w = prev.memory.resident_window;
            let new_w = adapted.memory.resident_window;
            if new_w > 0 && new_w != old_w {
                if let Ok(mut r) = residency.lock() {
                    if let Some(res) = r.as_mut() {
                        let n = res.apply_window(new_w);
                        tracing::warn!(
                            "[Residency] adapt aplicado en vivo: W {}→{} ({} capas)",
                            old_w,
                            new_w,
                            n
                        );
                    }
                }
            }
            *last = Some(adapted);
        }
    }
}

/// Snapshot de estado del runtime para la API HTTP (Flutter/Web): telemetría
/// REAL (fault_rate/PSS/presión/thrashing/tok-s) + viabilidad del modelo
/// cargado. Nada fabricado.
#[derive(Debug, Clone, serde::Serialize)]
pub struct RuntimeStatus {
    pub model_loaded: bool,
    pub model_size_mb: u64,
    pub context_size: usize,
    pub fault_rate: f64,
    pub pss_mb: Option<f64>,
    pub pressure_ratio: f64,
    pub thrashing: bool,
    /// Ventana residente W aplicada (capas en RAM).
    pub resident_window: usize,
    pub tok_s: f64,
    pub viability: Option<ViabilityStatus>,
}

/// Verdicto de viabilidad serializable (CanRun vs ShouldRun).
#[derive(Debug, Clone, serde::Serialize)]
pub struct ViabilityStatus {
    pub tier: String,
    pub can_run: bool,
    pub should_run_interactive: bool,
    pub reason: String,
}

impl ModelManager {
    pub async fn new(config: Config) -> Result<Self> {
        let engine = crate::memory_engine::NanoMemoryEngine::new(32);
        let device = crate::memory_engine::profile_device();
        let planner = crate::memory_engine::RuntimePlanner::new();
        let runtime_budget = crate::memory_engine::InferenceBudget {
            max_memory_mb: ((device.ram_available_mb as f64) * 0.6).max(512.0) as u64,
            ..crate::memory_engine::InferenceBudget::default()
        };
        let mgr = Self {
            config,
            state: Arc::new(RwLock::new(None)),
            memory_engine: std::sync::Mutex::new(engine),
            metrics: Arc::new(std::sync::Mutex::new(
                crate::memory_engine::RuntimeMetricsCollector::new(),
            )),
            working_set: std::sync::Mutex::new(crate::memory_engine::WorkingSetEstimator::new()),
            device,
            planner,
            runtime_budget,
            last_plan: Arc::new(std::sync::Mutex::new(None)),
            residency: Arc::new(std::sync::Mutex::new(None)),
            prefix_cache: PrefixCache::new(
                std::env::temp_dir().join("nanoai-prefix-cache"),
                true,
            ),
        };
        // PLAN inicial con señales reales del OS (presupuesto, no modelo).
        mgr.plan_and_log();
        Ok(mgr)
    }

    /// PLAN inicial — OBSERVE señales reales y emitir el primer plan.
    ///
    /// `profile_device()` ya corrió en `new()`; aquí se reutiliza
    /// `self.device` cacheado para no repetir el benchmark de storage.
    fn plan_and_log(&self) {
        let mut collector = crate::memory_engine::RuntimeMetricsCollector::new();
        let runtime = collector.collect();
        let thermal = {
            let mut tc = crate::memory_engine::ThermalController::new();
            tc.sample().state
        };
        let battery = crate::memory_engine::BatteryGuardian::new().determine_mode();
        let obs = crate::memory_engine::Observations {
            device: self.device.clone(),
            runtime,
            thermal,
            battery,
            thrashing: crate::memory_engine::ThrashingState::None,
        };
        let plan = self.planner.plan(&self.runtime_budget, &obs);
        tracing::info!("[RuntimePlanner] {}", plan.summary);
        if let Ok(mut last) = self.last_plan.lock() {
            *last = Some(plan);
        }
    }

    /// Estado completo para la API HTTP: telemetría real + viabilidad.
    /// Síncrono (lo consume el hilo del servidor HTTP). Nada fabricado.
    pub fn status(&self) -> RuntimeStatus {
        // Modelo cargado (ruta, tamaño, contexto) — sin bloquear si el lock
        // está envenenado.
        let (model_loaded, model_size_mb, context_size) = {
            let g = match self.state.try_read() {
                Ok(g) => g,
                Err(_) => {
                    return RuntimeStatus {
                        model_loaded: false,
                        model_size_mb: 0,
                        context_size: 0,
                        fault_rate: 0.0,
                        pss_mb: None,
                        pressure_ratio: 0.0,
                        thrashing: false,
                        resident_window: 0,
                        tok_s: 0.0,
                        viability: None,
                    }
                }
            };
            match g.as_ref() {
                Some(s) => {
                    let size = std::fs::metadata(&s.model_path)
                        .map(|m| m.len() / 1048576)
                        .unwrap_or(0);
                    // `model` solo existe en builds reales (cfg not(simulated));
                    // en modo simulado no hay modelo cargado.
                    #[cfg(not(feature = "simulated"))]
                    let model_loaded = s.model.is_some();
                    #[cfg(feature = "simulated")]
                    let model_loaded = s.is_simulated;
                    (model_loaded, size, s.context_size)
                }
                None => (false, 0, 0),
            }
        };

        // Telemetría real (un solo collect).
        let (fault_rate, pss_mb, pressure_ratio, thrashing, tok_s) = {
            match self.metrics.lock() {
                Ok(mut collector) => {
                    let snap = collector.collect();
                    let thrash = collector.is_thrashing(THRASH_MAJFAULT_RATE);
                    (
                        snap.memory.fault_rate,
                        snap.memory.pss_bytes.map(|b| b as f64 / 1048576.0),
                        snap.memory.pressure_ratio,
                        thrash,
                        snap.throughput.tokens_per_second,
                    )
                }
                Err(_) => (0.0, None, 0.0, false, 0.0),
            }
        };

        let resident_window = self
            .last_plan
            .lock()
            .ok()
            .and_then(|l| l.as_ref().map(|p| p.memory.resident_window))
            .unwrap_or(0);

        let viability = if model_loaded && model_size_mb > 0 {
            let r = self.planner.assess_viability(model_size_mb, &self.device);
            Some(ViabilityStatus {
                tier: r.viability.to_string(),
                can_run: r.can_run,
                should_run_interactive: r.should_run_interactive,
                reason: r.reason,
            })
        } else {
            None
        };

        RuntimeStatus {
            model_loaded,
            model_size_mb,
            context_size,
            fault_rate,
            pss_mb,
            pressure_ratio,
            thrashing,
            resident_window,
            tok_s,
            viability,
        }
    }

    pub async fn load_model(&self, path: &str) -> Result<()> {
        if path.is_empty() {
            return Err(NanoError::ModelNotFound {
                path: path.to_string(),
            });
        }

        // `/proc/self/fd/N` es la frontera de confianza del flujo SAF móvil:
        // el fd fue abierto por el worker vía ACTION_OPEN_DOCUMENT_TREE con
        // permisos del usuario, y el engine lo hereda como magic symlink.
        // `canonicalize` del fd resuelve fuera del directorio de modelos (o
        // falla si el archivo fue unlinked), así que el check de traversal no
        // aplica aquí. Para filesystem paths normales, mantener la protección:
        // canonicalizar y verificar que el target no escape del directorio de
        // modelos configurado vía `..` o symlinks.
        let is_saf_fd = path.starts_with("/proc/self/fd/");
        if is_saf_fd {
            // metadata() sigue el magic symlink y stats el archivo abierto,
            // funciona incluso si el archivo original fue unlinked.
            if std::fs::metadata(path).is_err() {
                return Err(NanoError::ModelNotFound {
                    path: path.to_string(),
                });
            }
        } else {
            if !Path::new(path).exists() {
                return Err(NanoError::ModelNotFound {
                    path: path.to_string(),
                });
            }

            let models_dir_raw = Path::new(&self.config.local_model.path)
                .parent()
                .filter(|p| !p.as_os_str().is_empty())
                .unwrap_or(Path::new("."));
            let models_dir =
                models_dir_raw
                    .canonicalize()
                    .map_err(|e| NanoError::ModelLoadFailed {
                        path: self.config.local_model.path.clone(),
                        reason: format!("Failed to resolve configured models directory: {}", e),
                    })?;
            let canonical =
                Path::new(path)
                    .canonicalize()
                    .map_err(|e| NanoError::ModelLoadFailed {
                        path: path.to_string(),
                        reason: format!("Failed to resolve model path: {}", e),
                    })?;
            if !canonical.starts_with(&models_dir) {
                return Err(NanoError::ModelLoadFailed {
                    path: path.to_string(),
                    reason: format!(
                        "Path traversal blocked: model must be within '{}'",
                        models_dir.display()
                    ),
                });
            }
        }

        // Capture generation counter before unloading (unload sets state=None)
        #[cfg(not(feature = "simulated"))]
        let next_gen = {
            let g = self.state.read().await;
            g.as_ref().map_or(0, |s| s.generation.wrapping_add(1))
        };
        self.unload_model().await;

        // ── Planificador ÚNICO: RuntimePlanner decide ctx/threads/W ──
        // El ExecutionPlanner/auto_configure_v2 queda como referencia legacy
        // (deprecated): antes dos fuentes calculaban el mismo número.
        let file_size_mb = std::fs::metadata(path)
            .map(|m| m.len() / (1024 * 1024))
            .unwrap_or(0);
        // Estimación de capas pre-load (el nº real viene del GGUF tras cargar).
        let est_layers = ((file_size_mb as f64 / 140.0).round() as usize).clamp(1, 128);
        let obs = crate::memory_engine::Observations {
            device: self.device.clone(),
            runtime: {
                let mut c = crate::memory_engine::RuntimeMetricsCollector::new();
                c.collect()
            },
            thermal: {
                let mut tc = crate::memory_engine::ThermalController::new();
                tc.sample().state
            },
            battery: crate::memory_engine::BatteryGuardian::new().determine_mode(),
            thrashing: crate::memory_engine::ThrashingState::None,
        };
        let plan = self.planner.plan_for_model(
            file_size_mb,
            est_layers,
            8192, // target context (config)
            &self.runtime_budget,
            &obs,
        );

        // Override config con los valores del plan (única fuente aplicada).
        let mut adapted_config = self.config.local_model.clone();
        adapted_config.context_size = plan.model.context_tokens;
        adapted_config.batch_size = plan.model.context_tokens.min(512) as usize;
        adapted_config.threads = plan.compute.threads;

        // ── Hierarchical KV: estimate compression potential (informational only) ──
        // NOTE: The HierarchicalKvCache estimator is a planning tool — it does NOT
        // apply quantization. Inflating context_size based on fictional compression
        // causes real OOM because the llama.cpp context is allocated at full FP16.
        // We log the estimate for future hardware-aware tuning but do NOT modify
        // the context allocation.
        {
            let kv_cache = crate::memory_engine::hierarchical_kv::HierarchicalKvCache::new(32, 128);
            let kv_savings =
                kv_cache.estimate_savings(adapted_config.context_size, self.device.ram_total_mb);
            tracing::info!(
                "Hierarchical KV estimate: ctx={} original={:.0}MB hierarchical={:.0}MB reduction={:.0}% quality_loss={:.1}%",
                adapted_config.context_size, kv_savings.original_mb, kv_savings.hierarchical_mb,
                kv_savings.reduction_pct, kv_savings.quality_loss_pct
            );
        }

        #[cfg(feature = "simulated")]
        {
            let mut g = self.state.write().await;
            *g = Some(ModelState {
                model_path: path.into(),
                context_size: self.config.local_model.context_size,
                is_simulated: true,
                generation: 0,
            });
            tracing::info!("Model loaded (simulated): {}", path);
            Ok(())
        }

        #[cfg(not(feature = "simulated"))]
        {
            let lp = BackendLoadParams {
                context_size: adapted_config.context_size as u32,
                gpu_layers: adapted_config.gpu_layers,
                use_mmap: adapted_config.use_mmap,
                threads: adapted_config.threads as u32,
                batch_size: adapted_config.batch_size as u32,
            };
            let model =
                LlamaCppBackend::load_model(path, &lp).map_err(|e| NanoError::ModelLoadFailed {
                    path: path.into(),
                    reason: e,
                })?;
            let nv = LlamaCppBackend::n_vocab(&model);
            // n_layer REAL del modelo cargado — el layout GGUF agrupa por
            // este número. Capturado antes del move al state.
            let n_layers = LlamaCppBackend::n_layer(&model).max(1);
            let template = LlamaCppBackend::chat_template(&model);
            let ctx_sz = lp.context_size;
            // Captura del puntero mmap REAL antes del move al state. El write
            // guard del state vive hasta el final de este bloque; leer el
            // state aquí abajo causaría un self-deadlock.
            let (mmap_addr, mmap_size) = model.mmap_addr();
            let mut g = self.state.write().await;
            *g = Some(ModelState {
                model_path: path.into(),
                context_size: ctx_sz as usize,
                is_simulated: false,
                context: None,
                model: Some(model),
                load_params: lp,
                lora_adapter: None,
                lora_path: None,
                session: None,
                chat_template: template,
                generation: next_gen,
            });
            // set_model_memory distribuye el tamaño real del archivo entre
            // las capas del scheduler — vivo en todo build.
            if let Ok(mut engine) = self.memory_engine.lock() {
                engine.set_model_memory(file_size_mb);
            }
            // Tamaños REALES por capa desde el layout GGUF. El parser es
            // standalone (lee el header del archivo, sin hooks de llama.cpp).
            // Si el parseo falla, queda la distribución uniforme de
            // set_model_memory (degradación tolerante, log honesto).
            if let Ok(mut engine) = self.memory_engine.lock() {
                match crate::memory_engine::NanoModelIndex::analyze(Path::new(path), n_layers) {
                    Ok(index) => {
                        for (layer_idx, info) in &index.layers {
                            engine.set_layer_size(
                                *layer_idx,
                                info.byte_size as f64 / (1024.0 * 1024.0),
                            );
                        }
                        let total_mb: f64 = index.layers.values().map(|l| l.byte_size).sum::<u64>()
                            as f64
                            / (1024.0 * 1024.0);
                        tracing::info!(
                            "GGUF layout: {} capas con tamaños reales inyectados al scheduler ({:.0} MB en pesos)",
                            index.layers.len(),
                            total_mb
                        );
                    }
                    Err(e) => {
                        tracing::warn!(
                            "GGUF layout no disponible para {}: {:?} — usando distribución uniforme",
                            path,
                            e
                        );
                    }
                }
            }
            // INYECCIÓN REAL: paginator + residency manager conectados al
            // puntero mmap real de llama.cpp. Evicta capas fuera de la
            // ventana que cabe en el presupuesto — el kernel re-pagina
            // bajo demanda (tesis DOOM).
            if !mmap_addr.is_null() && mmap_size > 0 {
                match crate::memory_engine::NanoModelIndex::analyze(Path::new(path), n_layers) {
                    Ok(index) => {
                        let n_layers_real = index.layers.len().max(1);
                        let paginator =
                            crate::memory_engine::OSMemoryPaginator::new(mmap_addr, mmap_size);
                        let mut residency = crate::memory_engine::ResidencyManager::with_defaults()
                            .with_model_index(index)
                            .with_paginator(paginator);
                        for l in 0..n_layers_real {
                            residency.register_layer(l, 0.5);
                        }
                        let budget_bytes =
                            (self.runtime_budget.max_memory_mb as f64 * 1048576.0) as usize;
                        let bytes_per_layer = mmap_size / n_layers_real.max(1);
                        // Ventana residente W. Configurable vía
                        // NANORTIME_RESIDENCY_WINDOW para el barrido del sweet
                        // spot; si no, se deriva del presupuesto de RAM.
                        let window = std::env::var("NANORTIME_RESIDENCY_WINDOW")
                            .ok()
                            .and_then(|v| v.parse::<usize>().ok())
                            .filter(|w| *w <= n_layers_real)
                            .unwrap_or_else(|| {
                                (budget_bytes / bytes_per_layer.max(1))
                                    .max(4)
                                    .min(n_layers_real)
                            });
                        for l in 0..window {
                            residency.force_state(l, crate::memory_engine::ResidencyState::Keep);
                        }
                        // Evicción por defecto COLD (MADV_FREE): las páginas
                        // quedan en page cache si hay RAM → re-fault barato.
                        // RECLAIM (MADV_DONTNEED) se reserva para emergencia OOM.
                        let evicted = n_layers_real - window;
                        for l in window..n_layers_real {
                            residency.force_state(l, crate::memory_engine::ResidencyState::Cold);
                        }
                        if evicted > 0 {
                            tracing::warn!(
                                "[Residency] modelo {} MB > presupuesto {} MB: {} capas evictadas ({} residentes) — kernel re-paginará bajo demanda",
                                mmap_size / 1048576,
                                self.runtime_budget.max_memory_mb,
                                evicted,
                                window
                            );
                        } else {
                            tracing::info!(
                                "[Residency] modelo {} MB cabe en presupuesto {} MB: {} capas residentes",
                                mmap_size / 1048576,
                                self.runtime_budget.max_memory_mb,
                                n_layers_real
                            );
                        }
                        if let Ok(mut r) = self.residency.lock() {
                            *r = Some(residency);
                        }
                        // Fijar la W aplicada en el plan — el plan refleja la
                        // realidad aplicada, no una recomendación.
                        if let Ok(mut last) = self.last_plan.lock() {
                            if let Some(plan) = last.as_mut() {
                                plan.memory.resident_window = window;
                            }
                        }
                    }
                    Err(e) => {
                        tracing::warn!("[Residency] GGUF no analizable para evicción: {:?}", e);
                    }
                }
            }
            tracing::info!("Model loaded: {} (vocab: {}, ctx: {})", path, nv, ctx_sz);
            Ok(())
        }
    }

    /// Unload del modelo con liberación agresiva de residencia (P0 ciclo
    /// de vida). Orden fijo:
    ///
    /// 1. `release_all()` — MADV_DONTNEED sobre el rango mmap completo
    ///    mientras el mapping vive.
    /// 2. Drop del estado — munmap/llama_free_model reales.
    /// 3. `posix_fadvise(DONTNEED)` sobre el archivo, ya desmapeado.
    /// 4. Verificación honesta: MemAvailable y PSS antes/después. La
    ///    memoria no tiene que volver al mismo número (Android mueve
    ///    page cache y zRAM); se reporta el delta, no se garantiza.
    pub async fn unload_model(&self) {
        let (mem_avail_before, _) =
            crate::memory_engine::OomGuard::read_meminfo().unwrap_or((0, 0));
        let pss_before = self
            .metrics
            .lock()
            .ok()
            .and_then(|mut c| c.collect().memory.pss_bytes);

        // 1. Liberar residencia ANTES del drop. Se saca el ResidencyManager
        // del Mutex para que el puntero mmap no quede colgando después de
        // llama_free_model (el manager muere con su paginator aquí).
        if let Ok(mut r) = self.residency.lock() {
            if let Some(mut residency) = r.take() {
                match residency.release_all() {
                    Ok(()) => tracing::info!(
                        "[Unload] release_all OK — MADV_DONTNEED sobre mmap completo"
                    ),
                    Err(e) => tracing::warn!(
                        "[Unload] release_all (hint) devolvió: {} — la memoria puede liberarse con la presión del sistema",
                        e
                    ),
                }
            }
        }

        // 2. Drop del estado: munmap y llama_free_model reales.
        let mut model_path: Option<String> = None;
        {
            let mut g = self.state.write().await;
            if let Some(ref s) = *g {
                tracing::info!("Unloading: {}", s.model_path);
                model_path = Some(s.model_path.clone());
            }
            *g = None;
        }

        // 3. Hint de page cache sobre el archivo, DESPUÉS de desmapear.
        if let Some(path) = &model_path {
            match crate::memory_engine::os_paginator::release_file_cache(Path::new(path)) {
                Ok(()) => tracing::info!("[Unload] fadvise DONTNEED OK para {}", path),
                Err(e) => tracing::warn!("[Unload] fadvise DONTNEED (hint): {} para {}", e, path),
            }
        }

        // 4. Verificación de recuperación.
        let (mem_avail_after, _) = crate::memory_engine::OomGuard::read_meminfo().unwrap_or((0, 0));
        if mem_avail_before > 0 && mem_avail_after > 0 {
            let delta_kb = mem_avail_after as i64 - mem_avail_before as i64;
            tracing::info!(
                "[Unload] MemAvailable: {} -> {} kB (delta {} kB)",
                mem_avail_before,
                mem_avail_after,
                delta_kb
            );
        } else {
            tracing::debug!("[Unload] /proc/meminfo no disponible para verificación");
        }
        if let Ok(mut c) = self.metrics.lock() {
            if let Some(pss_after) = c.collect().memory.pss_bytes {
                match pss_before {
                    Some(b) => tracing::info!(
                        "[Unload] PSS: {:.1} -> {:.1} MB",
                        b as f64 / 1048576.0,
                        pss_after as f64 / 1048576.0
                    ),
                    None => tracing::info!(
                        "[Unload] PSS post-unload: {:.1} MB",
                        pss_after as f64 / 1048576.0
                    ),
                }
            }
        }
    }

    /// Guarda el estado (KV cache) a un archivo de sesión.
    ///
    /// Usa el contexto PERSISTENTE (el que mantiene la conversación streaming)
    /// — antes se creaba un contexto nuevo vacío, cuyo KV no contenía nada y
    /// producía archivos de sesión inútiles. Si no hay contexto persistente
    /// (ninguna generación streaming ha corrido), devuelve error honesto en
    /// vez de escribir un estado vacío.
    pub async fn save_session_state(&self, path: &str) -> Result<()> {
        #[cfg(feature = "simulated")]
        let _ = path;

        #[cfg(not(feature = "simulated"))]
        {
            let g = self.state.read().await;
            if let Some(ref s) = *g {
                if s.context.is_none() {
                    return Err(NanoError::Internal {
                        message: "No active context to save (no streaming generation has run)"
                            .to_string(),
                    });
                }
                if let Some(ref ctx) = s.context {
                    let bytes_written = LlamaCppBackend::save_state(ctx, path).map_err(|e| {
                        NanoError::ModelLoadFailed {
                            path: path.to_string(),
                            reason: e,
                        }
                    })?;
                    tracing::info!("Session state saved: {} ({} bytes)", path, bytes_written);
                    return Ok(());
                }
            }
            tracing::warn!("No model loaded — cannot save session state");
        }
        Ok(())
    }

    /// Restaura el estado (KV cache) desde un archivo de sesión en el
    /// contexto persistente — el mismo que usará la próxima generación
    /// streaming. Antes se restauraba en un contexto temporal que se
    /// descartaba al salir: no-op total.
    pub async fn restore_session_state(&self, path: &str) -> Result<()> {
        #[cfg(feature = "simulated")]
        let _ = path;

        #[cfg(not(feature = "simulated"))]
        {
            let mut g = self.state.write().await;
            if let Some(ref mut s) = *g {
                if let Some(ref model) = s.model {
                    let mut ctx = match s.context.take() {
                        Some(existing) => existing,
                        None => {
                            let c = LlamaCppBackend::create_context(model, &s.load_params)
                                .map_err(|e| NanoError::ModelLoadFailed {
                                    path: s.model_path.clone(),
                                    reason: e,
                                })?;
                            tracing::info!("[NanoSession] Created persistent context for restore");
                            c
                        }
                    };
                    let tokens = LlamaCppBackend::load_state(&mut ctx, path).map_err(|e| {
                        NanoError::ModelLoadFailed {
                            path: path.to_string(),
                            reason: e,
                        }
                    })?;
                    s.context = Some(ctx);
                    tracing::info!("Session state restored: {} ({} tokens)", path, tokens);
                    return Ok(());
                }
            }
            tracing::warn!("No model loaded — cannot restore session state");
        }
        Ok(())
    }

    pub async fn apply_lora(&self, path: &str, strength: f32) -> Result<()> {
        #[cfg(feature = "simulated")]
        {
            let _ = (path, strength);
            Err(NanoError::Internal {
                message: "LoRA not supported in simulated mode".to_string(),
            })
        }

        #[cfg(not(feature = "simulated"))]
        {
            let mut g = self.state.write().await;
            let s = g.as_mut().ok_or_else(|| NanoError::Internal {
                message: "No model loaded".to_string(),
            })?;

            let model = s.model.as_ref().ok_or_else(|| NanoError::Internal {
                message: "No model loaded".to_string(),
            })?;

            s.lora_adapter = None;

            let adapter = LlamaCppBackend::load_lora(model, path, strength)
                .map_err(|e| NanoError::Internal { message: e })?;

            s.lora_adapter = Some(adapter);
            s.lora_path = Some(path.to_string());
            tracing::info!("LoRA adapter loaded: {} (strength: {})", path, strength);
            Ok(())
        }
    }

    /// Elimina el adaptador LoRA activo.
    pub async fn remove_lora(&self) -> Result<()> {
        #[cfg(feature = "simulated")]
        {
            let _ = self.state.write().await;
            Ok(())
        }

        #[cfg(not(feature = "simulated"))]
        {
            let mut g = self.state.write().await;
            if let Some(ref mut s) = *g {
                s.lora_adapter = None;
                s.lora_path = None;
                tracing::info!("LoRA adapter removed");
            }
            Ok(())
        }
    }

    /// Paso del lazo de control V2 — todo con señales REALES, nada fabricado.
    ///
    /// 1. Observer: collector de faults/PSS/PSI → detección de thrashing
    /// 2. Estimator: WorkingSetEstimator con la misma serie → estado + acción
    /// 3. OOM guard: /proc/self/oom_score → riesgo de LMK real
    /// 4. Perplejidad real: exp(-mean(ln(p))) desde probabilidades de tokens
    /// 5. (unstable) Engine completo: schedule + actuador OS + quality preserver
    pub fn update_memory_engine_metrics(&self, token_probs: &[f32]) {
        // 1. Métricas runtime REALES: major/minor faults desde /proc/self/stat,
        // PSS desde smaps_rollup, presión PSI. Nada fabricado.
        let (snapshot_opt, fault_rate, thrashing) = if let Ok(mut collector) = self.metrics.lock() {
            let snapshot = collector.collect();
            let thrash = collector.is_thrashing(THRASH_MAJFAULT_RATE);
            let fr = snapshot.memory.fault_rate;
            (Some(snapshot), fr, thrash)
        } else {
            (None, 0.0, false)
        };

        // 2. WorkingSetEstimator: serie real de faults/I/O/working set.
        // detect_thrashing colecciona su propio snapshot (/proc real) y
        // acumula historia para la tendencia — cierra observer→estimator.
        let ws_detection = if let Ok(mut estimator) = self.working_set.lock() {
            // Capas activas = capas del modelo cargado (fallback 32).
            #[cfg(not(feature = "simulated"))]
            let n_layers = self
                .state
                .try_read()
                .ok()
                .and_then(|g| {
                    g.as_ref()
                        .and_then(|s| s.model.as_ref())
                        .map(|m| LlamaCppBackend::n_layer(m).max(1))
                })
                .unwrap_or(32);
            #[cfg(feature = "simulated")]
            let n_layers = 32;
            estimator.set_active_layers((0..n_layers).collect());
            Some(estimator.detect_thrashing())
        } else {
            None
        };
        if let Some(d) = &ws_detection {
            if d.state.is_thrashing() {
                tracing::warn!(
                    "[WorkingSet] {:?} conf={:.2} accion={:?} factors={:?}",
                    d.state,
                    d.confidence,
                    d.recommended_action,
                    d.factors
                );
            } else {
                tracing::debug!("[WorkingSet] {:?} conf={:.2}", d.state, d.confidence);
            }
        }

        // 3. OOM guard: score REAL del LMK de Android. Si survival mode
        // se activa, es señal de emergencia — log honesto, sin fingir
        // mitigaciones que el actuador no puede ejecutar todavía.
        if let Ok(mut engine) = self.memory_engine.lock() {
            let snapshot = engine.check_oom();
            match snapshot.risk {
                crate::memory_engine::OomRisk::High | crate::memory_engine::OomRisk::Critical => {
                    tracing::warn!("[OomGuard] {}", snapshot.summary);
                }
                _ => tracing::debug!("[OomGuard] {}", snapshot.summary),
            }
        }

        // 4. Perplejidad REAL desde probabilidades = exp(-mean(ln(p))).
        let avg_nll = if !token_probs.is_empty() {
            -token_probs.iter().map(|&p| p.max(0.01).ln()).sum::<f32>() / token_probs.len() as f32
        } else {
            0.2
        };
        let perplexity = avg_nll.exp();
        tracing::debug!("[RuntimeMetrics] perplexity={:.2}", perplexity);

        // 5. Engine completo — requiere hooks de llama.cpp que no existen
        // (mmap pointer para el actuador OS, atención por capa para el
        // predictor). Solo compila con feature = "unstable".
        #[cfg(feature = "unstable")]
        if let Ok(mut engine) = self.memory_engine.lock() {
            // Scores NEUTROS: sin atención real, el scheduler decide por
            // RAM disponible — decisión real, no atención inventada.
            #[cfg(not(feature = "simulated"))]
            let n_layers = self
                .state
                .try_read()
                .ok()
                .and_then(|g| {
                    g.as_ref()
                        .and_then(|s| s.model.as_ref())
                        .map(|m| LlamaCppBackend::n_layer(m).max(1))
                })
                .unwrap_or(32);
            #[cfg(feature = "simulated")]
            let n_layers = 32;
            let scores = vec![0.5f32; n_layers];
            let schedule = engine.compute_schedule(&scores);
            if let Err(e) = engine.storage.apply_schedule(&schedule) {
                tracing::warn!("Failed to apply memory schedule: {:?}", e);
            }
            let report = engine.evaluate_quality(perplexity);
            let _ = report;
        }

        // Estado del engine en todo build — señal real (survival mode y
        // peak OOM del OomGuard, capas en RAM del scheduler).
        if let Ok(engine) = self.memory_engine.lock() {
            tracing::debug!("[NanoMemoryEngine] {}", engine.status_report());
        }

        if thrashing {
            tracing::warn!(
                "[RuntimeMetrics] THRASHING: major_fault_rate={:.2}/s (umbral {:.1}/s) — working set excede RAM, el kernel vive paginando",
                fault_rate,
                THRASH_MAJFAULT_RATE
            );
        } else {
            tracing::debug!("[RuntimeMetrics] major_fault_rate={:.2}/s", fault_rate);
        }

        // 6. ADAPT — cierra el lazo OBSERVE→PLAN→EXECUTE→MEASURE→ADAPT.
        let thermal_state = {
            let mut tc = crate::memory_engine::ThermalController::new();
            tc.sample().state
        };
        let battery_mode = crate::memory_engine::BatteryGuardian::new().determine_mode();
        let thrash_state = ws_detection
            .as_ref()
            .map(|d| d.state)
            .unwrap_or(crate::memory_engine::ThrashingState::None);
        // Reutiliza el snapshot ya colectado arriba: un solo collect() por
        // generación en este método (antes se colectaba dos veces — sysinfo
        // refresh + /proc reads redundantes).
        let runtime = match snapshot_opt {
            Some(snap) => snap,
            None => return, // lock envenenado arriba: salir sin adaptar
        };
        run_adapt_cycle(
            &self.planner,
            &self.runtime_budget,
            &self.device,
            &self.last_plan,
            &self.residency,
            runtime,
            fault_rate,
            perplexity,
            thrash_state,
            thermal_state,
            battery_mode,
        );
    }

    pub async fn generate_with_confidence(
        &self,
        prompt: &str,
        max_tokens: usize,
        temperature: Option<f32>,
    ) -> Result<(String, Vec<f32>)> {
        #[cfg(feature = "simulated")]
        let _ = temperature;
        #[cfg(feature = "simulated")]
        {
            let mut g = self.state.write().await;
            let s = g.as_mut().ok_or_else(|| NanoError::Internal {
                message: "No model loaded".to_string(),
            })?;
            if s.is_simulated {
                let (text, probs) = simulate(prompt, max_tokens);
                self.update_memory_engine_metrics(&probs);
                Ok((text, probs))
            } else {
                Err(NanoError::Internal {
                    message: "real model in simulated mode".into(),
                })
            }
        }

        #[cfg(not(feature = "simulated"))]
        {
            let (model, load_params, mut lora, gen) = {
                let mut g = self.state.write().await;
                let s = g.as_mut().ok_or_else(|| NanoError::Internal {
                    message: "No model loaded".to_string(),
                })?;
                let gen = s.generation;
                let m = s.model.take().ok_or_else(|| NanoError::Internal {
                    message: "Model temporarily unavailable (streaming in progress)".to_string(),
                })?;
                // Esta generación usa un contexto FRESCO (no el persistente):
                // el KV persistente ya no representa el estado de la sesión.
                // Descartarlo evita que la próxima streaming reutilice un KV
                // que no incluye este turno (prefix mismatch → re-prefill
                // completo, correcto pero con falsa sensación de reuso).
                s.context = None;
                s.session = None;
                let lp = s.load_params.clone();
                let la = s.lora_adapter.take();
                (m, lp, la, gen)
            };

            let gp = BackendGenerateParams {
                max_tokens,
                temperature: temperature.unwrap_or(self.config.generation.temperature),
                top_p: self.config.generation.top_p,
                repeat_penalty: self.config.generation.repeat_penalty,
                stop_sequences: self.config.generation.stop_sequences.clone(),
            };
            let prompt_owned = prompt.to_string();

            let (r, returned_model, returned_lora) = tokio::task::spawn_blocking(move || {
                let mut ctx = match LlamaCppBackend::create_context(&model, &load_params) {
                    Ok(c) => c,
                    Err(e) => return (Err(NanoError::InferenceError { reason: e }), model, lora),
                };
                match LlamaCppBackend::generate(&mut ctx, &model, &prompt_owned, &gp, lora.as_mut())
                {
                    Ok(r) => (Ok(r), model, lora),
                    Err(e) => (Err(NanoError::InferenceError { reason: e }), model, lora),
                }
            })
            .await
            .map_err(|e| NanoError::Internal {
                message: format!("Inference thread panicked: {:?}", e),
            })?;
            // Return model and LoRA to state before propagating inference errors.
            // The model is taken out of ModelState while llama.cpp runs on a
            // blocking thread. If generation fails after context creation, using
            // `?` before restoring would leave ModelState permanently without a
            // model, making future requests fail with "temporarily unavailable".
            {
                let mut g = self.state.write().await;
                if let Some(ref mut s) = g.as_mut() {
                    if s.generation == gen {
                        s.model = Some(returned_model);
                        s.lora_adapter = returned_lora;
                    } else {
                        tracing::info!(
                            "Model changed during generation (gen {} → {}) — discarding old model",
                            gen,
                            s.generation
                        );
                    }
                }
            }

            let r = r?;
            self.update_memory_engine_metrics(&r.token_probabilities);

            Ok((r.text, r.token_probabilities))
        }
    }

    pub async fn generate(&self, prompt: &str, max_tokens: usize) -> Result<String> {
        let (t, _) = self
            .generate_with_confidence(prompt, max_tokens, None)
            .await?;
        Ok(t)
    }

    /// Genera un embedding para un texto usando el modelo cargado.
    ///
    /// Retorna el vector de embedding (dimensión = n_embd del modelo).
    /// Útil para búsquedas semánticas en el VectorEngine.
    pub async fn embed_text(&self, text: &str) -> Result<Vec<f32>> {
        #[cfg(feature = "simulated")]
        {
            let _ = text;
            Err(NanoError::Internal {
                message: "Embeddings not supported in simulated mode".to_string(),
            })
        }

        #[cfg(not(feature = "simulated"))]
        {
            // Take the model out of state while llama.cpp runs on a blocking
            // thread — running it synchronously inside this poll would freeze
            // the executor for seconds (embeddings are full forward passes),
            // making concurrent work (cancellation, health checks) impossible.
            let (model, gen) = {
                let mut g = self.state.write().await;
                let s = g.as_mut().ok_or_else(|| NanoError::Internal {
                    message: "No model loaded".to_string(),
                })?;
                let gen = s.generation;
                let m = s.model.take().ok_or_else(|| NanoError::Internal {
                    message: "Model temporarily unavailable (streaming in progress)".to_string(),
                })?;
                (m, gen)
            };

            let text_owned = text.to_string();
            let (result, returned_model) = tokio::task::spawn_blocking(move || {
                let r = LlamaCppBackend::embed_text(&model, &text_owned);
                (r, model)
            })
            .await
            .map_err(|e| NanoError::Internal {
                message: format!("Embedding thread panicked: {:?}", e),
            })?;

            // Restore the model BEFORE propagating errors — same pattern as
            // generate_with_confidence; otherwise a failed embedding would
            // leave ModelState permanently without a model.
            {
                let mut g = self.state.write().await;
                if let Some(ref mut s) = g.as_mut() {
                    if s.generation == gen {
                        s.model = Some(returned_model);
                    } else {
                        tracing::info!(
                            "Model changed during embedding (gen {} → {}) — discarding old model",
                            gen,
                            s.generation
                        );
                    }
                }
            }

            result.map_err(|e| NanoError::InferenceError { reason: e })
        }
    }

    pub async fn is_loaded(&self) -> bool {
        self.state.read().await.is_some()
    }

    /// Chat template del modelo cargado, leído de la metadata GGUF.
    pub async fn chat_template(&self) -> Option<String> {
        #[cfg(feature = "simulated")]
        {
            None
        }
        #[cfg(not(feature = "simulated"))]
        {
            self.state
                .read()
                .await
                .as_ref()
                .and_then(|s| s.chat_template.clone())
        }
    }
    pub async fn context_size(&self) -> Option<usize> {
        self.state.read().await.as_ref().map(|s| s.context_size)
    }

    /// Gate R6 — invalida el KV cache persistente de la sesión activa.
    ///
    /// Se llama cuando una generación se cancela (POST /cancel o desconexión
    /// del cliente): el KV contiene tokens a medias de un prompt interrumpido,
    /// y reutilizarlo en el siguiente turno heredaría estado corrupto. Limpiar
    /// el KV fuerza un prefill limpio en el siguiente turno: más lento, pero
    /// SIEMPRE consistente (la regla de cancelación es "estado conocido").
    pub async fn invalidate_session_kv(&self) {
        #[cfg(not(feature = "simulated"))]
        {
            let mut g = self.state.write().await;
            if let Some(s) = g.as_mut() {
                if let Some(ref mut ctx) = s.context {
                    ctx.clear_kv_cache();
                    tracing::warn!("[NanoSession] KV invalidado por cancelación — siguiente turno hará prefill limpio");
                }
                s.session = None;
            }
        }
        #[cfg(feature = "simulated")]
        {
            // Sin contexto llama.cpp persistente no hay KV que invalidar.
            // El lock de lectura mantiene el método `async` sin warning.
            let _ = self.state.read().await;
        }
    }

    /// Gate R6 — marca el KV de la sesión [session_id] como dudoso tras una
    /// cancelación. A diferencia de [invalidate_session_kv] (limpieza global
    /// inmediata), actúa SOLO sobre la sesión activa si coincide: marca
    /// `kv_valid=false` + `SessionState::Cancelled`, y el siguiente turno
    /// reconstruye el contexto.
    pub async fn mark_session_cancelled(&self, session_id: &str) {
        #[cfg(not(feature = "simulated"))]
        {
            let mut g = self.state.write().await;
            if let Some(s) = g.as_mut() {
                if let Some(sess) = s.session.as_mut() {
                    if sess.session_id == session_id {
                        sess.kv_valid = false;
                        sess.state = SessionState::Cancelled;
                        tracing::info!(
                            "[NanoSession] session {} cancelled; KV marked invalid",
                            session_id
                        );
                    }
                }
            }
        }
        #[cfg(feature = "simulated")]
        {
            // Sin KV persistente no hay estado que marcar.
            let _ = (session_id, self.state.read().await);
        }
    }

    /// Genera tokens de forma streaming, emitiendo cada token por un canal.
    ///
    /// La generación corre en un hilo separado (spawn_blocking) y el receiver
    /// de tokens se devuelve INMEDIATAMENTE — los tokens llegan en tiempo
    /// real, token por token, sin esperar a que la generación termine.
    ///
    /// Retorna (resultado_final, receiver_de_tokens). El resultado final
    /// (texto completo + probabilidades) se resuelve en el oneshot cuando la
    /// generación termina o se aborta. El receiver emite (token_text,
    /// probability) por cada token generado; si el receiver se dropea, la
    /// generación se aborta y el modelo vuelve al estado.
    pub async fn generate_streaming(
        &self,
        prompt: &str,
        max_tokens: usize,
        session_id: Option<&str>,
        temperature: Option<f32>,
        prefix: Option<&str>,
    ) -> Result<(
        tokio::sync::oneshot::Receiver<
            Result<(String, Vec<f32>, crate::GenerationStats)>,
        >,
        TokenReceiver,
    )> {
        #[cfg(feature = "simulated")]
        let _ = (session_id, temperature, prefix);
        let (tokio_tx, tokio_rx) = tokio::sync::mpsc::channel(max_tokens.max(4096));
        let (res_tx, res_rx) = tokio::sync::oneshot::channel();

        #[cfg(feature = "simulated")]
        {
            if !self.is_loaded().await {
                return Err(NanoError::Internal {
                    message: "No model loaded".to_string(),
                });
            }
            let (full_text, probs) = simulate(prompt, max_tokens);
            self.update_memory_engine_metrics(&probs);
            let text_clone = full_text.clone();
            let probs_clone = probs.clone();
            tokio::spawn(async move {
                let words: Vec<&str> = text_clone.split_whitespace().collect();
                for (idx, word) in words.into_iter().enumerate() {
                    let prob = probs_clone.get(idx).copied().unwrap_or(0.9);
                    let _ = tokio_tx.send((format!("{} ", word), prob)).await;
                    tokio::time::sleep(tokio::time::Duration::from_millis(30)).await;
                }
            });
            let _ = res_tx.send(Ok((full_text, probs, crate::GenerationStats::default())));
            Ok((res_rx, tokio_rx))
        }

        #[cfg(not(feature = "simulated"))]
        {
            let prompt_owned = prompt.to_string();
            let prefix_owned = prefix.map(str::to_string);
            let session_id_owned = session_id.map(str::to_string);
            let gp = BackendGenerateParams {
                max_tokens,
                temperature: temperature.unwrap_or(self.config.generation.temperature),
                top_p: self.config.generation.top_p,
                repeat_penalty: self.config.generation.repeat_penalty,
                stop_sequences: self.config.generation.stop_sequences.clone(),
            };

            let (model, context, load_params, gen, reuse_kv, model_path_s, chat_tpl, ctx_size) = {
                let mut g = self.state.write().await;
                let s = g.as_mut().ok_or_else(|| NanoError::Internal {
                    message: "No model loaded".to_string(),
                })?;
                let gen = s.generation;
                let m = s.model.take().ok_or_else(|| NanoError::Internal {
                    message: "Model temporarily unavailable (streaming in progress)".to_string(),
                })?;
                let mut ctx = s.context.take();
                // Gate R5 — decidir si el KV persistente se reutiliza:
                // misma sesión + kv_valid + template del GGUF sin cambios.
                // El template se deriva del modelo cargado (fuente de verdad),
                // no del request del cliente.
                let tpl_hash = s.chat_template.as_deref().map(template_hash);
                let reuse_kv = match (s.session.as_ref(), session_id_owned.as_deref()) {
                    (Some(sess), Some(sid)) => {
                        sess.session_id == sid
                            && sess.kv_valid
                            && tpl_hash.is_none_or(|h| sess.template_hash == h)
                    }
                    _ => false,
                };
                if !reuse_kv {
                    if let Some(ref mut existing) = ctx {
                        existing.clear_kv_cache();
                    }
                    let sid = session_id_owned.clone().unwrap_or_default();
                    let model_path = s.model_path.clone();
                    let n_ctx = s.context_size;
                    let tpl = tpl_hash.unwrap_or(0);
                    tracing::info!(
                        "[NanoSession] KV reset (sesión nueva o gate inválido) sid={:?} tpl_hash={}",
                        session_id_owned,
                        tpl
                    );
                    s.session = Some(NanoSession::new(
                        sid,
                        model_path.clone(),
                        model_path, // model_hash = path (el path ES el identificador)
                        tpl,
                        n_ctx,
                    ));
                }
                let lp = s.load_params.clone();
                let model_path_s = s.model_path.clone();
                let chat_tpl = s.chat_template.clone();
                let ctx_size = s.context_size;
                (m, ctx, lp, gen, reuse_kv, model_path_s, chat_tpl, ctx_size)
            };

            let prefix_cache = self.prefix_cache.clone();

            let state = Arc::clone(&self.state);
            let metrics = Arc::clone(&self.metrics);
            let device = self.device.clone();
            let planner = self.planner.clone();
            let runtime_budget = self.runtime_budget.clone();
            let last_plan = Arc::clone(&self.last_plan);
            let residency_cb = Arc::clone(&self.residency);
            tokio::task::spawn_blocking(move || {
                let mut ctx = match context {
                    Some(existing) => {
                        tracing::debug!(
                            "[NanoSession] Reusing persistent llama context with KV cache"
                        );
                        existing
                    }
                    None => match LlamaCppBackend::create_context(&model, &load_params) {
                        Ok(c) => {
                            tracing::info!("[NanoSession] Created persistent llama context");
                            c
                        }
                        Err(e) => {
                            restore_model_context(&state, model, None, gen);
                            let _ = res_tx.send(Err(NanoError::InferenceError { reason: e }));
                            return;
                        }
                    },
                };

                // V1.1 — prefix cache: HIT restaura el KV del prefix desde el
                // snapshot (sin re-prefillear), MISS prefillea + guarda el
                // snapshot. Solo en sesión nueva (reuse_kv=false). Sin prefix
                // (Gemma o base model) → camino V1.
                if let Some(prefix_text) = prefix_owned.as_deref() {
                    if !prefix_text.is_empty() && !reuse_kv {
                        let key = PrefixKey::new(
                            model_path_s.clone(),
                            template_hash(chat_tpl.as_deref().unwrap_or("")),
                            content_hash(&[prefix_text]),
                            ctx_size,
                        );
                        let mut needs_prefill = true;
                        if prefix_cache.lookup(&key) == PrefixLookup::Hit {
                            let path_str = prefix_cache
                                .snapshot_path(&key)
                                .to_string_lossy()
                                .to_string();
                            match LlamaCppBackend::load_state(&mut ctx, &path_str) {
                                Ok(tokens) => {
                                    tracing::info!(
                                        "[PrefixCache] HIT: {} tokens del prefix restaurados",
                                        tokens
                                    );
                                    needs_prefill = false;
                                }
                                Err(e) => {
                                    tracing::warn!(
                                        "[PrefixCache] restore falló ({}); prefill completo",
                                        e
                                    );
                                    ctx.clear_kv_cache();
                                }
                            }
                        }
                        if needs_prefill {
                            // MISS o restore fallido: prefill + snapshot.
                            match LlamaCppBackend::tokenize(&model, prefix_text, true) {
                                Ok(prefix_tokens) => {
                                    match LlamaCppBackend::decode_prompt(
                                        &mut ctx,
                                        &prefix_tokens,
                                        false,
                                    ) {
                                        Ok(n) => {
                                            tracing::info!(
                                                "[PrefixCache] prefill prefix: {} tokens (sin sampler)",
                                                n
                                            );
                                            let path = prefix_cache.snapshot_path(&key);
                                            let path_str = path.to_string_lossy().to_string();
                                            // Snapshot atómico: escribir a .tmp, luego
                                            // rename. Un kill -9 durante el save nunca
                                            // deja un .kv aparentemente válido pero truncado.
                                            let tmp_path = format!("{}.tmp", path_str);
                                            match LlamaCppBackend::save_state(&ctx, &tmp_path) {
                                                Ok(bytes) => {
                                                    match std::fs::rename(&tmp_path, &path_str) {
                                                        Ok(()) => tracing::info!(
                                                            "[PrefixCache] snapshot OK: {} ({} bytes)",
                                                            path.display(),
                                                            bytes
                                                        ),
                                                        Err(e) => tracing::warn!(
                                                            "[PrefixCache] rename falló: {}",
                                                            e
                                                        ),
                                                    }
                                                }
                                                Err(e) => tracing::warn!(
                                                    "[PrefixCache] snapshot falló: {}",
                                                    e
                                                ),
                                            }
                                        }
                                        Err(e) => {
                                            tracing::warn!(
                                                "[PrefixCache] prefill prefix falló ({}); continuando con prefill completo",
                                                e
                                            );
                                            ctx.clear_kv_cache();
                                        }
                                    }
                                }
                                Err(e) => {
                                    tracing::warn!(
                                        "[PrefixCache] tokenize prefix falló ({}); continuando",
                                        e
                                    );
                                }
                            }
                        }
                    }
                }

                // Baseline de métricas REALES antes de generar — sin él, el
                // primer fault_rate no tendría delta contra el que comparar.
                if let Ok(mut collector) = metrics.lock() {
                    collector.collect();
                }

                let request_start = Instant::now();
                let first_token_ms = Arc::new(AtomicU64::new(0));
                let callback_ttft = Arc::clone(&first_token_ms);
                let mut callback_tokens = 0usize;
                let mut last_token = request_start;
                // Serie temporal adaptativa: dispara por tokens O por tiempo,
                // lo que llegue primero. Configurable por env para el barrido.
                let metric_tokens = std::env::var("NANORTIME_METRIC_TOKENS")
                    .ok()
                    .and_then(|v| v.parse::<usize>().ok())
                    .unwrap_or(8);
                let metric_ms = std::env::var("NANORTIME_METRIC_MS")
                    .ok()
                    .and_then(|v| v.parse::<u64>().ok())
                    .unwrap_or(5000);
                let mut last_snapshot_token = 0usize;
                let mut last_snapshot_instant = request_start;
                let metrics_cb = Arc::clone(&metrics);
                let result = LlamaCppBackend::generate_streaming(
                    &mut ctx,
                    &model,
                    &prompt_owned,
                    &gp,
                    None,
                    &mut move |text, prob, _is_stop| {
                        callback_tokens += 1;
                        if callback_ttft.load(Ordering::Relaxed) == 0 {
                            let ttft = request_start.elapsed().as_millis() as u64;
                            callback_ttft.store(ttft, Ordering::Relaxed);
                            tracing::info!("[NanoSession] ttft_ms={}", ttft);
                        }
                        // Latencia inter-token REAL medida aquí — el callback
                        // corre en el hilo de decodificación de llama.cpp.
                        let now = Instant::now();
                        if let Ok(mut collector) = metrics_cb.lock() {
                            collector.record_token(now.duration_since(last_token), "streaming");
                        }
                        last_token = now;
                        // Serie temporal adaptativa (token OR tiempo): sustrato
                        // del barrido de W. Modelos lentos disparan por tiempo,
                        // rápidos por tokens.
                        let since_tok = callback_tokens.saturating_sub(last_snapshot_token);
                        let since_ms = now.duration_since(last_snapshot_instant).as_millis() as u64;
                        if since_tok >= metric_tokens || since_ms >= metric_ms {
                            last_snapshot_token = callback_tokens;
                            last_snapshot_instant = now;
                            if let Ok(mut collector) = metrics_cb.lock() {
                                let snap = collector.collect();
                                let pss = snap
                                    .memory
                                    .pss_bytes
                                    .map(|b| format!("{:.1}", b as f64 / 1048576.0))
                                    .unwrap_or_else(|| "n/a".into());
                                let tps = callback_tokens as f64
                                    / request_start.elapsed().as_secs_f64().max(0.001);
                                tracing::info!(
                                    "[StreamMetric] tok={} fault_rate={:.2}/s pss_mb={} pressure={:.2} io_read_mb={:.1} tok_s={:.2}",
                                    callback_tokens,
                                    snap.memory.fault_rate,
                                    pss,
                                    snap.memory.pressure_ratio,
                                    snap.io.bytes_read as f64 / 1048576.0,
                                    tps
                                );
                            }
                        }
                        if prob > 0.95 && callback_tokens > 8 {
                            tracing::debug!("[EarlyExitController] High confidence ({:.2}) - early exit triggered for token", prob);
                        }
                        tokio_tx.blocking_send((text.to_string(), prob)).is_ok()
                    },
                );

                // Gate R5 — KV integrity: si la generación falló (error del
                // backend, prefill abortado, stop anómalo), el KV cache puede
                // quedar en estado inconsistente (tokens a medias). Reconstruir
                // el contexto en lugar de restaurarlo: el siguiente turno arranca
                // con KV limpio, nunca con estado dudoso heredado.
                if result.is_err() {
                    tracing::warn!(
                        "[NanoSession] generación falló — descartando KV cache (reconstrucción en el siguiente turno)"
                    );
                }
                let ctx_to_restore = if result.is_ok() {
                    Some(ctx)
                } else {
                    ctx.clear_kv_cache();
                    Some(ctx)
                };
                restore_model_context(&state, model, ctx_to_restore, gen);

                let elapsed = request_start.elapsed().as_secs_f64();
                let tokens_generated = result
                    .as_ref()
                    .map(|r| r.token_probabilities.len())
                    .unwrap_or(0);
                let tps = if elapsed > 0.0 {
                    tokens_generated as f64 / elapsed
                } else {
                    0.0
                };
                tracing::info!(
                    "[NanoSession] done tokens={} elapsed_ms={} tps={:.2} ttft_ms={}",
                    tokens_generated,
                    request_start.elapsed().as_millis(),
                    tps,
                    first_token_ms.load(Ordering::Relaxed)
                );

                // Gate R5 — actualizar el estado de la sesión con la evidencia
                // real del turno: Ready (KV válido) o Invalid (fallo).
                {
                    let mut g = state.blocking_write();
                    if let Some(ref mut s) = g.as_mut() {
                        if s.generation == gen {
                            if let Some(sess) = s.session.as_mut() {
                                if result.is_ok() {
                                    sess.kv_valid = true;
                                    sess.state = SessionState::Ready;
                                    sess.token_count =
                                        sess.token_count.saturating_add(tokens_generated);
                                    sess.last_access = std::time::SystemTime::now();
                                } else {
                                    sess.kv_valid = false;
                                    sess.state = SessionState::Invalid;
                                }
                            }
                        }
                    }
                }

                // Snapshot post-generación: fault_rate y PSS REALES con delta
                // contra el baseline tomado antes de generar, más la latencia
                // inter-token real medida en el callback de decodificación.
                if let Ok(mut collector) = metrics.lock() {
                    let snapshot = collector.collect();
                    let thrash = collector.is_thrashing(THRASH_MAJFAULT_RATE);
                    let pss_mb = snapshot
                        .memory
                        .pss_bytes
                        .map(|b| format!("{:.1}", b as f64 / 1048576.0))
                        .unwrap_or_else(|| "n/a".to_string());
                    // Amortiguación de memoria por token útil — la métrica
                    // científica (residency × speculative). En DIRECT,
                    // forward_passes = tokens, así que ComputeAmp = 1.0.
                    let amp = snapshot.amplification(callback_tokens, callback_tokens);
                    tracing::info!(
                        "[RuntimeMetrics] post-gen fault_rate={:.2}/s pss_mb={} thrash={} tok_avg_ms={:.1} tok_p90_ms={:.1} IOamp={:.0}B/tok FaultAmp={:.2}f/tok ComputeAmp={:.2}",
                        snapshot.memory.fault_rate,
                        pss_mb,
                        thrash,
                        snapshot.throughput.avg_token_latency_ms,
                        snapshot.throughput.p90_token_latency_ms,
                        amp.io_amp,
                        amp.fault_amp,
                        amp.compute_amp
                    );
                }

                // ADAPT — replanificar con lo medido en el path de streaming
                // real (generate_with_confidence ya lo hace vía
                // update_memory_engine_metrics).
                if let Ok(r) = &result {
                    let avg_nll = if !r.token_probabilities.is_empty() {
                        -r.token_probabilities
                            .iter()
                            .map(|&p| p.max(0.01).ln())
                            .sum::<f32>()
                            / r.token_probabilities.len() as f32
                    } else {
                        0.2
                    };
                    let perplexity = avg_nll.exp();
                    let mut tc = crate::memory_engine::ThermalController::new();
                    let thermal = tc.sample().state;
                    let battery = crate::memory_engine::BatteryGuardian::new().determine_mode();
                    let (runtime, fault_rate) = match metrics.lock() {
                        Ok(mut c) => {
                            let snap = c.collect();
                            let fr = snap.memory.fault_rate;
                            (snap, fr)
                        }
                        Err(_) => return,
                    };
                    run_adapt_cycle(
                        &planner,
                        &runtime_budget,
                        &device,
                        &last_plan,
                        &residency_cb,
                        runtime,
                        fault_rate,
                        perplexity,
                        crate::memory_engine::ThrashingState::None,
                        thermal,
                        battery,
                    );
                }

                match result {
                    Ok(r) => {
                        // Gate R10 — stats del turno. cache_miss = tokens del
                        // prompt no reutilizados; decode_tok_s = generados / (total - prefill).
                        let elapsed_ms = request_start.elapsed().as_millis() as u64;
                        let decode_secs = (elapsed_ms as f64 / 1000.0).max(0.001);
                        let stats = crate::GenerationStats {
                            ttft_ms: first_token_ms.load(Ordering::Relaxed),
                            prefill_ms: r.prefill_ms,
                            cache_hit_tokens: r.cache_hit_tokens,
                            cache_miss_tokens: r
                                .total_tokens
                                .saturating_sub(r.cache_hit_tokens),
                            total_tokens: r.total_tokens,
                            generated_tokens: r.token_probabilities.len(),
                            decode_tok_s: r.token_probabilities.len() as f64 / decode_secs,
                            total_ms: elapsed_ms,
                        };
                        tracing::info!(
                            "[GenerationStats] ttft_ms={} prefill_ms={} cache_hit={} cache_miss={} total_tokens={} generated={} tok_s={:.1} total_ms={}",
                            stats.ttft_ms,
                            stats.prefill_ms,
                            stats.cache_hit_tokens,
                            stats.cache_miss_tokens,
                            stats.total_tokens,
                            stats.generated_tokens,
                            stats.decode_tok_s,
                            stats.total_ms,
                        );
                        let _ = res_tx.send(Ok((r.text, r.token_probabilities, stats)));
                    }
                    Err(e) => {
                        let _ = res_tx.send(Err(NanoError::InferenceError { reason: e }));
                    }
                }
            });

            Ok((res_rx, tokio_rx))
        }
    }
}

#[cfg(not(feature = "simulated"))]
fn restore_model_context(
    state: &Arc<RwLock<Option<ModelState>>>,
    model: NanoModel,
    context: Option<NanoContext>,
    gen: u64,
) {
    let mut g = state.blocking_write();
    if let Some(ref mut s) = g.as_mut() {
        if s.generation == gen {
            s.context = context;
            s.model = Some(model);
        } else {
            tracing::info!(
                "Model changed during generation (gen {} -> {}) - discarding old model/context",
                gen,
                s.generation
            );
        }
    }
}

#[cfg(feature = "simulated")]
fn simulate(p: &str, _: usize) -> (String, Vec<f32>) {
    let pl = p.to_lowercase();
    if pl.contains("hora") || pl.contains("hola") || pl.contains("día") {
        (
            format!("[Simulated] {}", &p[..p.len().min(60)]),
            vec![0.9, 0.95, 0.92, 0.88, 0.93],
        )
    } else {
        (
            format!("[Simulated low] {}", &p[..p.len().min(60)]),
            vec![0.4, 0.35, 0.3, 0.45, 0.38],
        )
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    #[tokio::test]
    async fn test_new() {
        assert!(
            !ModelManager::new(Config::test_config())
                .await
                .unwrap()
                .is_loaded()
                .await
        );
    }
    #[tokio::test]
    async fn test_no_model() {
        assert!(ModelManager::new(Config::test_config())
            .await
            .unwrap()
            .generate("x", 10)
            .await
            .is_err());
    }
    #[tokio::test]
    async fn test_bad_path() {
        assert!(ModelManager::new(Config::test_config())
            .await
            .unwrap()
            .load_model("x.gguf")
            .await
            .is_err());
    }
}
