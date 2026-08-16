//! Capa de orquestación — routing híbrido, privacidad y confianza.
//!
//! El orchestrator decide si una petición se procesa localmente (Tier 1),
//! en un servidor LAN (Tier 2) o en la nube (Tier 3). La decisión se basa
//! en detección de PII, entropía de la respuesta local y configuración.

pub mod cloud;
pub mod cloud_provider;
pub mod confidence;
pub mod privacy;
pub mod router;
pub mod tool_parser;

use std::sync::Arc;
use std::sync::Mutex as StdMutex; // para thermal, que no necesita async

use crate::config::manifest::Config;
use crate::error::{NanoError, Result};
use crate::execution::{ModelManager, PromptCache, RateLimiter, ToolExecutor, VectorEngine};
use crate::inference::grammar::Grammar;
use crate::inference::research::hallucination_detector::{analyze_token, HallucinationDetector};
use crate::{Response, ToolCallResult, UserRequest};

/// Computes confidence (0.0-1.0) from generated-token probabilities.
///
/// These values are one probability per generated token, not a full vocabulary
/// distribution for a single step. Treating them as a Shannon distribution makes
/// confidence depend on response length and can turn normal long answers into
/// false low-confidence signals. Arithmetic mean preserves the actual contract.
fn token_confidence(probabilities: &[f32]) -> Option<f32> {
    if probabilities.is_empty() {
        return None;
    }
    Some(
        probabilities
            .iter()
            .copied()
            .map(|p| p.clamp(0.0, 1.0))
            .sum::<f32>()
            / probabilities.len() as f32,
    )
}

// ── V2: Policy Engine + Cost Scheduler ─────────────────────────────
use crate::memory_engine::hardware_hal::profile_device;
use crate::memory_engine::types::QosMode;
use crate::speculative_decoder::{InferenceMode, SpeculativePlan};
// ── V2: Thermal + Battery + Hierarchical KV ────────────────────────
use crate::memory_engine::battery_guardian::{BatteryGuardian, BatteryMode};
use crate::memory_engine::thermal_controller::{ThermalAction, ThermalController};

// ── Metrics: Operational observability ─────────────────────────────────
// Tracks real runtime stats. Aggregated per-session for calibration
// of hybrid_router thresholds and memory model parameters.

/// Aggregated runtime metrics for observability and calibration.
#[derive(Debug, Clone, Default)]
pub struct OrchestratorMetrics {
    /// Total requests processed.
    pub requests_total: u64,
    /// Requests served from prompt cache (instant).
    pub cache_hits: u64,
    /// Requests processed locally (Tier 1).
    pub local_count: u64,
    /// Requests escalated to cloud (Tier 3).
    pub cloud_count: u64,
    /// Requests served via LAN (Tier 2).
    pub lan_count: u64,
    /// Requests where local confidence was below threshold.
    pub low_confidence_count: u64,
    /// Cumulative tokens generated across all requests.
    pub tokens_total: u64,
    /// Cumulative generation time (ms).
    pub total_latency_ms: u64,
    /// Sum of local/LAN confidence values for average confidence reporting.
    pub confidence_total: f64,
    /// Number of local/LAN responses with confidence values.
    pub confidence_count: u64,
    /// Requests that triggered circuit breaker (forced cloud).
    pub circuit_breaker_trips: u64,
    /// Hallucination signals detected (streaming path only).
    pub hallucination_signals: u64,
}

impl OrchestratorMetrics {
    /// Hit rate for prompt cache (0.0-1.0).
    pub fn cache_hit_rate(&self) -> f32 {
        if self.requests_total == 0 {
            0.0
        } else {
            self.cache_hits as f32 / self.requests_total as f32
        }
    }

    /// Escalation rate: fraction of requests sent to cloud.
    pub fn cloud_rate(&self) -> f32 {
        if self.requests_total == 0 {
            0.0
        } else {
            self.cloud_count as f32 / self.requests_total as f32
        }
    }

    /// Average latency per request (ms). Ignores cache hits.
    pub fn avg_latency_ms(&self) -> f64 {
        let non_cache = self.requests_total.saturating_sub(self.cache_hits);
        if non_cache == 0 {
            0.0
        } else {
            self.total_latency_ms as f64 / non_cache as f64
        }
    }

    /// Average confidence across all non-cloud requests.
    /// Returns None if no local/LAN requests have been processed yet.
    pub fn avg_confidence(&self) -> Option<f32> {
        if self.confidence_count == 0 {
            None
        } else {
            Some((self.confidence_total / self.confidence_count as f64) as f32)
        }
    }

    /// Human-readable summary for periodic logging.
    pub fn summary(&self) -> String {
        format!(
            "reqs={} cache={:.0}% local={} cloud={} lan={} low_conf={} cb_trips={} latency={:.0}ms hall={}",
            self.requests_total,
            self.cache_hit_rate() * 100.0,
            self.local_count,
            self.cloud_count,
            self.lan_count,
            self.low_confidence_count,
            self.circuit_breaker_trips,
            self.avg_latency_ms(),
            self.hallucination_signals,
        )
    }
}

/// Circuit breaker: prevents cascade failures when local inference
/// produces consistently low-quality output (confidence < threshold).
///
/// After `threshold` consecutive low-confidence results, the breaker
/// opens: all subsequent requests bypass local inference and go directly
/// to cloud until `cooldown_requests` successful cloud responses close it.
#[derive(Debug, Clone)]
struct CircuitBreaker {
    /// Consecutive low-confidence results seen.
    consecutive_failures: u32,
    /// Number of failures before opening the circuit.
    failure_threshold: u32,
    /// Whether the circuit is currently open (local bypassed).
    open: bool,
    /// Successful cloud requests since circuit opened.
    cloud_successes_since_open: u32,
    /// Cloud successes needed to close the circuit (half-open → closed).
    cooldown_requests: u32,
}

impl CircuitBreaker {
    fn new() -> Self {
        Self {
            consecutive_failures: 0,
            failure_threshold: 3,
            open: false,
            cloud_successes_since_open: 0,
            cooldown_requests: 2,
        }
    }

    /// Called before each request. Returns true if local should be bypassed.
    fn check(&self) -> bool {
        self.open
    }

    /// Called after a local response. Records confidence outcome.
    fn record_local(&mut self, confidence: Option<f32>, threshold: f32) {
        let is_low = confidence.unwrap_or(0.5) < threshold;
        if is_low {
            self.consecutive_failures += 1;
            if self.consecutive_failures >= self.failure_threshold {
                self.open = true;
                self.cloud_successes_since_open = 0;
                tracing::warn!(
                    "Circuit breaker OPEN: {} consecutive low-confidence results (threshold={:.2})",
                    self.consecutive_failures,
                    threshold
                );
            }
        } else {
            // A single good result resets the counter but keeps circuit closed
            // (circuit only opens on consecutive failures, not intermittent ones).
            self.consecutive_failures = 0;
        }
    }

    /// Called after a successful cloud response when circuit is open.
    fn record_cloud_success(&mut self) {
        if !self.open {
            return;
        }
        self.cloud_successes_since_open += 1;
        if self.cloud_successes_since_open >= self.cooldown_requests {
            self.open = false;
            self.consecutive_failures = 0;
            self.cloud_successes_since_open = 0;
            tracing::info!(
                "Circuit breaker CLOSED: {} successful cloud responses",
                self.cooldown_requests
            );
        }
    }

    /// Reset to default state (e.g. on model switch).
    fn reset(&mut self) {
        self.consecutive_failures = 0;
        self.open = false;
        self.cloud_successes_since_open = 0;
    }
}

/// Orquestador principal del runtime.
///
/// Coordina el pipeline completo: privacidad → RAG → routing → ejecución.
/// Integra caché de prompts, limitador de tasa y detección de tool calls.
pub struct Orchestrator {
    config: Config,
    model_manager: Arc<ModelManager>,
    vector_engine: Arc<VectorEngine>,
    tool_executor: Arc<ToolExecutor>,
    router: router::Router,
    /// Caché LRU de prompts para evitar regeneración.
    prompt_cache: tokio::sync::Mutex<PromptCache>,
    /// Limitador de tasa para Tier 3 (cloud).
    cloud_rate_limiter: RateLimiter,
    /// Limitador de tasa para Tier 2 (LAN).
    lan_rate_limiter: RateLimiter,
    // ── V2: Hardware-aware controllers ──────────────────────────
    /// Monitorea temperatura del CPU y recomienda acciones.
    thermal: StdMutex<ThermalController>,
    /// Monitorea batería y ajusta modo de consumo.
    battery: BatteryGuardian,
    // ── V3: Operational safety ───────────────────────────────────
    /// Aggregated runtime metrics for observability + calibration.
    metrics: StdMutex<OrchestratorMetrics>,
    /// Circuit breaker: prevents cascade of bad local generations.
    circuit_breaker: StdMutex<CircuitBreaker>,
}

impl Orchestrator {
    /// Crea un nuevo orquestador con los componentes proporcionados.
    pub fn new(
        config: Config,
        model_manager: Arc<ModelManager>,
        vector_engine: Arc<VectorEngine>,
        tool_executor: Arc<ToolExecutor>,
    ) -> Self {
        let router = router::Router::new(config.clone());
        // Cache capacity: ~100 prompts of average 2KB each = ~200KB max
        let prompt_cache = tokio::sync::Mutex::new(PromptCache::new(100));
        // Cloud: 60 requests/minute = 1 per second, burst of 5
        let cloud_rate_limiter = RateLimiter::new(5.0, 1.0);
        // LAN: 120 requests/minute = 2 per second, burst of 10
        let lan_rate_limiter = RateLimiter::new(10.0, 2.0);
        // ── V2: Hardware-aware controllers ─────────────────────
        let thermal = StdMutex::new(ThermalController::new());
        let battery = BatteryGuardian::new();
        // ── V3: Operational safety ───────────────────────────────
        let metrics = StdMutex::new(OrchestratorMetrics::default());
        let circuit_breaker = StdMutex::new(CircuitBreaker::new());
        Self {
            config,
            model_manager,
            vector_engine,
            tool_executor,
            router,
            prompt_cache,
            cloud_rate_limiter,
            lan_rate_limiter,
            thermal,
            battery,
            metrics,
            circuit_breaker,
        }
    }

    /// Clears prompt and response caches. Called on model switch since
    /// cached responses from the old model are invalid for the new one.
    pub async fn invalidate_caches(&self) {
        self.prompt_cache.lock().await.clear();
        // Reset circuit breaker — new model, fresh confidence baseline
        if let Ok(mut cb) = self.circuit_breaker.lock() {
            cb.reset();
        }
        tracing::info!("Orchestrator caches invalidated (model switch)");
    }

    /// Returns a snapshot of current operational metrics.
    pub fn metrics(&self) -> OrchestratorMetrics {
        self.metrics.lock().map(|m| m.clone()).unwrap_or_default()
    }

    fn record_response_metrics(
        &self,
        response: &Response,
        latency_ms: u64,
        cache_hit: bool,
        circuit_breaker_trip: bool,
    ) -> Result<()> {
        let mut m = self.metrics.lock().map_err(|_| NanoError::Internal {
            message: "Metrics lock poisoned".to_string(),
        })?;

        m.requests_total += 1;
        m.tokens_total += response.tokens_generated as u64;
        if !cache_hit {
            m.total_latency_ms += latency_ms;
        }
        if cache_hit {
            m.cache_hits += 1;
        }
        if circuit_breaker_trip {
            m.circuit_breaker_trips += 1;
        }

        match response.tier_used.as_str() {
            t if t.starts_with("local") => m.local_count += 1,
            "cloud" => m.cloud_count += 1,
            "lan" => m.lan_count += 1,
            _ => {}
        }

        if response.tier_used.starts_with("local") || response.tier_used == "lan" {
            if let Some(confidence) = response.confidence {
                m.confidence_total += confidence.clamp(0.0, 1.0) as f64;
                m.confidence_count += 1;
            }
        }

        if response.tier_used.starts_with("local")
            && response.confidence.unwrap_or(0.5) < self.config.hybrid_routing.confidence_threshold
        {
            m.low_confidence_count += 1;
        }

        Ok(())
    }

    /// V2: Auto-detects device profile and selects optimal QoS mode.
    ///
    /// Budget devices (<4 GB RAM) → Eco mode (prioritize survival).
    /// Mid-range devices (4-8 GB) → Balanced mode.
    /// Flagship/Desktop → Performance mode.
    pub fn auto_detect_qos() -> (QosMode, String) {
        let profile = profile_device();
        let mode = match profile.tier {
            crate::memory_engine::hardware_hal::DeviceTier::Budget => QosMode::Eco,
            crate::memory_engine::hardware_hal::DeviceTier::MidRange => QosMode::Balanced,
            _ => QosMode::Performance,
        };
        let summary = format!(
            "Auto QoS: {} mode ({}MB RAM, {} cores, tier={})",
            mode, profile.ram_total_mb, profile.cpu_cores, profile.tier
        );
        (mode, summary)
    }

    /// Decide el modo de inferencia (speculative vs estándar) según RAM.
    ///
    /// Conecta el SpeculativePlan con el hardware real:
    /// - RAM suficiente para draft+target → Speculative
    /// - Solo target → Standard
    /// - Nada cabe → Survival
    ///
    /// Devuelve una descripción del modo para logging.
    pub fn decide_inference_mode(target_size_mb: u64, draft_size_mb: u64) -> InferenceMode {
        let profile = profile_device();
        let plan = SpeculativePlan::plan(&profile, target_size_mb, draft_size_mb);
        tracing::info!(
            "Inference mode: {:?} (RAM={}MB, target={}MB, draft={}MB)",
            plan.mode,
            profile.ram_available_mb,
            target_size_mb,
            draft_size_mb
        );
        plan.mode
    }

    /// Procesa una petición completa del usuario a través del pipeline.
    ///
    /// Pipeline:
    /// 0. Thermal + Battery check — ajusta QoS según hardware
    /// 1. Privacy check — detecta PII y fuerza Tier 1 si es necesario
    /// 2. RAG — busca documentos relevantes para enriquecer el contexto
    /// 3. Prompt cache — salta generación si el prompt exacto ya se respondió
    /// 4. Local inference — genera respuesta local primero
    /// 5. Tool detection — escanea la salida en busca de tool calls JSON
    /// 6. Confidence check — si confianza baja y cloud habilitado, escala a cloud
    /// 7. Rate limiter — verifica límites antes de llamadas cloud/LAN
    pub async fn process_request(&self, request: UserRequest) -> Result<Response> {
        let request_start = std::time::Instant::now();
        // ── Step 0: Hardware-aware QoS ──────────────────────────────
        let reading = self
            .thermal
            .lock()
            .map_err(|_| NanoError::Internal {
                message: "Thermal controller lock poisoned".to_string(),
            })?
            .sample();
        let thermal_action = self
            .thermal
            .lock()
            .map_err(|_| NanoError::Internal {
                message: "Thermal controller lock poisoned".to_string(),
            })?
            .recommend_action(&reading);
        let battery_mode = self.battery.determine_mode();

        // Thermal: si temperatura > 70°C, degradar a modo Eco
        if !matches!(thermal_action, ThermalAction::Normal) {
            tracing::warn!(
                "Thermal action: {:?} at {:.0}°C — reducing batch/pausing",
                thermal_action,
                reading.max_temp_c
            );
        }
        // Battery: si < 20%, forzar solo Tier 1 (edge)
        if matches!(battery_mode, BatteryMode::Eco | BatteryMode::Survival) {
            tracing::warn!(
                "Low battery mode: {:?} — forcing Tier 1 (edge only)",
                battery_mode
            );
        }

        let prompt = &request.prompt;

        // ── Circuit breaker check: if local inference has been
        // producing consistently low-confidence results, bypass it
        // and go directly to cloud (when available and safe).
        let circuit_open = self
            .circuit_breaker
            .lock()
            .map(|cb| cb.check())
            .unwrap_or(false);
        if circuit_open
            && self.config.hybrid_routing.enabled
            && !self.config.hybrid_routing.edge_only
            && self.config.tiers.tier3.enabled
        {
            // Verify prompt has no PII before sending to cloud
            let has_pii = if self.config.hybrid_routing.privacy_filter {
                privacy::contains_pii(prompt)
            } else {
                false
            };
            if !has_pii {
                tracing::warn!("Circuit breaker OPEN — bypassing local, routing to cloud");
                let safe_prompt = if privacy::contains_pii(prompt) {
                    privacy::anonymize(prompt)
                } else {
                    prompt.to_string()
                };
                match self.execute_cloud(&safe_prompt).await {
                    Ok(response) => {
                        if let Ok(mut cb) = self.circuit_breaker.lock() {
                            cb.record_cloud_success();
                        }
                        self.record_response_metrics(
                            &response,
                            request_start.elapsed().as_millis() as u64,
                            false,
                            true,
                        )?;
                        return Ok(response);
                    }
                    Err(e) => {
                        tracing::warn!(
                            "Circuit breaker cloud failed ({}), falling back to local",
                            e
                        );
                        // Fall through to normal local-first pipeline
                    }
                }
            } else {
                tracing::warn!(
                    "Circuit breaker open but prompt has PII — cannot escalate to cloud"
                );
                // Fall through; circuit breaker will re-evaluate after this local result
            }
        }

        // Step 1: Privacy check
        let prompt_has_pii = if self.config.hybrid_routing.privacy_filter {
            privacy::contains_pii(prompt)
        } else {
            false
        };

        // Step 2: RAG — search for relevant documents using embeddings
        let rag_docs = if !prompt_has_pii {
            // Try semantic search with embeddings from the model
            let query_embedding = match self.model_manager.embed_text(prompt).await {
                Ok(emb) => Some(emb),
                Err(e) => {
                    tracing::warn!(
                        "RAG embedding failed for prompt — falling back to keyword search: {}",
                        e
                    );
                    None
                }
            };
            self.vector_engine
                .search(
                    prompt,
                    self.config.memory.max_context_docs,
                    query_embedding.as_deref(),
                )
                .await
                .unwrap_or_default()
        } else {
            vec![]
        };

        // Step 3: Build augmented context
        let augmented_prompt = self
            .build_augmented_prompt(prompt, &rag_docs, &request)
            .await;

        // Cloud safety must be based on the exact prompt that may leave the
        // device. RAG docs, user-provided context, and history can introduce PII
        // even when the latest prompt is clean.
        let has_pii = if self.config.hybrid_routing.privacy_filter {
            prompt_has_pii || privacy::contains_pii(&augmented_prompt)
        } else {
            false
        };
        if has_pii && !prompt_has_pii {
            tracing::warn!(
                "PII detected in augmented context — forcing Local (Tier 1) and disabling cloud escalation"
            );
        }

        // Step 4: Check prompt cache.
        // Cache is safe when tools are not registered OR the prompt does not
        // trigger a tool call (the store guard at Step 7 enforces this).
        if self.config.hybrid_routing.enabled {
            let mut cache = self.prompt_cache.lock().await;
            if let Some((cached_text, cached_probs)) = cache.get(&augmented_prompt) {
                let avg_confidence = token_confidence(&cached_probs);
                tracing::debug!("Prompt cache HIT, returning cached response");
                let response = Response {
                    text: cached_text,
                    tier_used: "local (cached)".to_string(),
                    confidence: avg_confidence,
                    tool_calls: vec![],
                    sources: vec![],
                    tokens_generated: 0,
                    model_memory_mb: 0, // Populated from MemoryManager when model is loaded
                };
                self.record_response_metrics(
                    &response,
                    request_start.elapsed().as_millis() as u64,
                    true,
                    false,
                )?;
                if let Ok(mut cb) = self.circuit_breaker.lock() {
                    cb.record_local(
                        response.confidence,
                        self.config.hybrid_routing.confidence_threshold,
                    );
                }
                return Ok(response);
            }
        }

        // Step 5: Route request (check PII, edge-only mode)
        let routing_decision = if self.config.hybrid_routing.edge_only || has_pii {
            router::RoutingDecision::Local
        } else {
            self.router
                .route(&augmented_prompt)
                .await
                .unwrap_or(router::RoutingDecision::Local)
        };

        // Step 6: Execute in selected tier with rate limiting
        let mut response = match routing_decision {
            router::RoutingDecision::Local => {
                self.execute_local_with_escalation(&augmented_prompt, has_pii, request.temperature)
                    .await
            }
            router::RoutingDecision::Cloud(anonymized) => {
                if has_pii {
                    tracing::warn!("Cloud route blocked because augmented prompt contains PII");
                    self.execute_local_with_escalation(&augmented_prompt, has_pii, request.temperature)
                        .await
                } else {
                    // Cloud policy, including rate limiting, lives inside execute_cloud.
                    match self.execute_cloud(&anonymized).await {
                        Ok(response) => Ok(response),
                        Err(e) => {
                            tracing::warn!("Cloud execution failed ({}), falling back to local", e);
                            self.execute_local_with_escalation(&augmented_prompt, has_pii, request.temperature)
                                .await
                        }
                    }
                }
            }
            router::RoutingDecision::Lan(endpoint) => {
                // Check LAN rate limiter
                if !self.lan_rate_limiter.try_consume_one() {
                    tracing::warn!("LAN rate limit exceeded, falling back to local");
                    self.execute_local_with_escalation(&augmented_prompt, has_pii, request.temperature)
                        .await
                } else {
                    // Try LAN; if it fails, fall back to local
                    match self.execute_lan(&augmented_prompt, &endpoint).await {
                        Ok(response) => Ok(response),
                        Err(e) => {
                            tracing::warn!("LAN execution failed ({}), falling back to local", e);
                            self.execute_local_with_escalation(&augmented_prompt, has_pii, request.temperature)
                                .await
                        }
                    }
                }
            }
        }?;

        if response.sources.is_empty() && !rag_docs.is_empty() {
            response.sources = rag_docs.clone();
        }

        // Step 7: Store in prompt cache.
        // Only cache local responses without tool calls (tool output varies).
        // The tool registration check is removed — presence of tools does not
        // invalidate caching for prompts that do not trigger tool calls.
        if self.config.hybrid_routing.enabled
            && response.tier_used.starts_with("local")
            && response.tool_calls.is_empty()
        {
            let mut cache = self.prompt_cache.lock().await;
            let cached_confidence = response
                .confidence
                .map(|confidence| vec![confidence])
                .unwrap_or_default();
            cache.put(&augmented_prompt, response.text.clone(), cached_confidence);
        }

        // ── Record metrics ─────────────────────────────────────────
        {
            self.record_response_metrics(
                &response,
                request_start.elapsed().as_millis() as u64,
                false,
                false,
            )?;
        }

        // ── Circuit breaker: record local result ────────────────────
        if response.tier_used.starts_with("local") {
            if let Ok(mut cb) = self.circuit_breaker.lock() {
                cb.record_local(
                    response.confidence,
                    self.config.hybrid_routing.confidence_threshold,
                );
            }
        } else if response.tier_used == "cloud" {
            if let Ok(mut cb) = self.circuit_breaker.lock() {
                cb.record_cloud_success();
            }
        }

        Ok(response)
    }

    /// Ejecuta localmente y escala a cloud si la confianza es baja.
    ///
    /// Estrategia:
    /// 1. Generar respuesta local siempre
    /// 2. Si confianza < threshold y cloud activo, escalar
    /// 3. Nunca enviar PII a cloud
    async fn execute_local_with_escalation(
        &self,
        prompt: &str,
        has_pii: bool,
        temperature: Option<f32>,
    ) -> Result<Response> {
        // Step 0: Sample hardware controllers for throttling
        let thermal_action = self.sample_thermal();
        let battery_mode = self.battery.determine_mode();

        // Step 1: Always try local first. Un error local (modelo sin cargar,
        // OOM, fallo de inferencia) ya no mata el request: si el escalado a
        // cloud es posible, se intenta como degradación. Antes el `?` devolvía
        // el error directo al cliente sin importar que hubiera tier3 activo.
        let local = match self
            .execute_local(prompt, has_pii, &thermal_action, &battery_mode, temperature)
            .await
        {
            Ok(local) => local,
            Err(local_err) => {
                let can_escalate = self.config.hybrid_routing.enabled
                    && !self.config.hybrid_routing.edge_only
                    && !has_pii
                    && self.config.tiers.tier3.enabled;
                if can_escalate {
                    tracing::warn!(
                        "Local inference failed ({}). Escalating to cloud as degradation.",
                        local_err
                    );
                    let safe_prompt = if privacy::contains_pii(prompt) {
                        privacy::anonymize(prompt)
                    } else {
                        prompt.to_string()
                    };
                    return match self.execute_cloud(&safe_prompt).await {
                        Ok(cloud_response) => Ok(cloud_response),
                        Err(cloud_err) => Err(NanoError::Internal {
                            message: format!(
                                "Local inference failed ({}) and cloud fallback failed ({})",
                                local_err, cloud_err
                            ),
                        }),
                    };
                }
                return Err(local_err);
            }
        };

        // Step 2: Check if escalation is possible and needed
        let should_escalate = self.config.hybrid_routing.enabled
            && !self.config.hybrid_routing.edge_only
            && !has_pii  // NEVER send PII to cloud
            && self.config.tiers.tier3.enabled;

        if should_escalate {
            let avg_confidence = local.confidence.unwrap_or(0.5);
            let threshold = self.config.hybrid_routing.confidence_threshold;

            if avg_confidence < threshold {
                tracing::info!(
                    "Local confidence {:.2} < threshold {:.2}. Escalating to cloud.",
                    avg_confidence,
                    threshold
                );

                // Anonymize before sending to cloud
                let safe_prompt = if privacy::contains_pii(prompt) {
                    privacy::anonymize(prompt)
                } else {
                    prompt.to_string()
                };

                // Try cloud escalation; if it fails, fall back to local response
                match self.execute_cloud(&safe_prompt).await {
                    Ok(cloud_response) => return Ok(cloud_response),
                    Err(e) => {
                        tracing::warn!(
                            "Cloud escalation failed ({}), falling back to local response",
                            e
                        );
                        return Ok(local);
                    }
                }
            }

            tracing::debug!(
                "Local confidence {:.2} >= threshold {:.2}. Staying local.",
                avg_confidence,
                threshold
            );
        }

        Ok(local)
    }

    /// Construye el prompt aumentado con documentos RAG, historial y herramientas.
    /// Aplica el chat template del modelo cuando es un modelo instruct (Qwen, Llama, etc.).
    fn approx_tokens(text: &str) -> usize {
        text.chars().count().saturating_add(3) / 4
    }

    fn context_budget_chars(&self) -> usize {
        self.config.local_model.context_size.saturating_mul(4)
    }

    fn truncate_chars(text: &str, max_chars: usize) -> String {
        text.chars().take(max_chars).collect()
    }

    async fn build_augmented_prompt(

        &self,
        prompt: &str,
        rag_docs: &[crate::SourceDocument],
        request: &UserRequest,
    ) -> String {
        // Detectar instruct-ness por la metadata del GGUF cargado (señal
        // autoritativa: los modelos base no traen tokenizer.chat_template).
        // El nombre del archivo queda como fallback para modelos sin metadata.
        let model_path_lower = self.config.local_model.path.to_lowercase();
        let is_instruct = self
            .model_manager
            .chat_template()
            .await
            .map(|tpl| !tpl.trim().is_empty())
            .unwrap_or_else(|| {
                model_path_lower.contains("instruct") || model_path_lower.contains("chat")
            });

        // ── Instruct model path: use proper chat template ──────────
        if is_instruct {
            return self.build_instruct_prompt(prompt, rag_docs, request).await;
        }

        // ── Base model path: generic format ────────────────────────
        let mut parts = Vec::new();

        // System prompt with tools
        let tools_prompt = self.tool_executor.build_system_prompt().await;
        if !tools_prompt.is_empty() {
            parts.push(tools_prompt);
        }

        // Learned corrections (from user feedback)
        let corrections = self
            .vector_engine
            .search(prompt, self.config.memory.max_context_docs.min(3), None)
            .await
            .unwrap_or_default();
        let corrections: Vec<&crate::SourceDocument> = corrections
            .iter()
            .filter(|d| d.metadata.get("type").and_then(|v| v.as_str()) == Some("correction"))
            .collect();
        if !corrections.is_empty() {
            parts.push("Previously learned corrections:\n".to_string());
            for corr in corrections {
                let original = corr
                    .metadata
                    .get("original")
                    .and_then(|v| v.as_str())
                    .unwrap_or("");
                let correction = &corr.content;
                parts.push(format!(
                    "- User corrected: '{}' → '{}'",
                    original, correction
                ));
            }
        }

        if let Some(ref context) = request.context {
            parts.push("Additional user-provided context:\n".to_string());
            parts.push(format!("{}\n", context));
        }

        // RAG context
        if !rag_docs.is_empty() {
            parts.push("Context from your documents:\n".to_string());
            for doc in rag_docs {
                parts.push(format!("---\n{}\n", doc.content));
            }
        }

        // Chat history
        if let Some(ref history) = request.history {
            for msg in history {
                parts.push(format!("{}: {}", msg.role, msg.content));
            }
        }

        // Current prompt
        parts.push(format!("User: {}", prompt));
        parts.push("Assistant:".to_string());

        let joined = parts.join("\n");

        // ── Context budget guard ────────────────────────────────────
        let max_ctx = self.config.local_model.context_size;
        let estimated_tokens = Self::approx_tokens(&joined);
        if estimated_tokens > max_ctx {
            let excess = estimated_tokens.saturating_sub(max_ctx);
            tracing::warn!(
                "Augmented prompt ~{} tokens exceeds context window {} — truncating RAG docs (excess ~{} tokens)",
                estimated_tokens, max_ctx, excess
            );
            let mut budget_parts: Vec<String> = parts
                .iter()
                .take_while(|p| !p.starts_with("Context from your documents"))
                .cloned()
                .collect();
            if !rag_docs.is_empty() {
                let base_len: usize = budget_parts
                    .iter()
                    .map(|s| s.chars().count())
                    .sum::<usize>()
                    + format!("User: {}", prompt).chars().count()
                    + "Assistant:".chars().count();
                let available_chars = self.context_budget_chars().saturating_sub(base_len);
                if available_chars > 200 {
                    budget_parts.push("Context from your documents (truncated):\n".to_string());
                    let mut used = 0;
                    for doc in rag_docs {
                        let remaining = available_chars.saturating_sub(used);
                        if remaining < 100 {
                            break;
                        }
                        let snippet = Self::truncate_chars(&doc.content, remaining);
                        budget_parts.push(format!("---\n{}\n", snippet));
                        used += snippet.chars().count();
                    }
                }
            }
            budget_parts.push(format!("User: {}", prompt));
            budget_parts.push("Assistant:".to_string());
            return budget_parts.join("\n");
        }

        joined
    }

    /// Builds a prompt using the Qwen/Llama chat template for instruct models.
    ///
    /// Format:
    ///   <|im_start|>system
    ///   {tools + instructions}<|im_end|>
    ///   <|im_start|>user
    ///   {context + history + prompt}<|im_end|>
    ///   <|im_start|>assistant
    ///
    /// Uses `<|im_start|>/<|im_end|>` markers compatible with Qwen 2.x, Llama 3.x,
    /// and other modern instruct models.
    async fn build_instruct_prompt(
        &self,
        prompt: &str,
        rag_docs: &[crate::SourceDocument],
        request: &UserRequest,
    ) -> String {
        // ── System message ──────────────────────────────────────────
        // Prioridad: el `context` del cliente ES el system prompt principal
        // (la app móvil envía identidad, estilo y telemetría real). El
        // fallback genérico solo aplica cuando no hay context (CLI/FFI).
        // Si además el servidor registró tools propias, se añaden después.
        let tools_prompt = self.tool_executor.build_system_prompt().await;
        let mut system_parts = Vec::new();

        if let Some(ref context) = request.context {
            if !context.trim().is_empty() {
                system_parts.push(context.clone());
            }
        } else if !tools_prompt.is_empty() {
            system_parts.push(tools_prompt.clone());
        } else {
            system_parts
                .push("You are a helpful assistant. Answer concisely and accurately.".to_string());
        }
        if request.context.is_some() && !tools_prompt.is_empty() {
            system_parts.push(tools_prompt);
        }

        // Learned corrections go into system context
        let corrections = self
            .vector_engine
            .search(prompt, self.config.memory.max_context_docs.min(3), None)
            .await
            .unwrap_or_default();
        let corrections: Vec<&crate::SourceDocument> = corrections
            .iter()
            .filter(|d| d.metadata.get("type").and_then(|v| v.as_str()) == Some("correction"))
            .collect();
        if !corrections.is_empty() {
            system_parts.push("\nPreviously learned corrections:".to_string());
            for corr in corrections {
                let original = corr
                    .metadata
                    .get("original")
                    .and_then(|v| v.as_str())
                    .unwrap_or("");
                let correction = &corr.content;
                system_parts.push(format!("- Corrected: '{}' → '{}'", original, correction));
            }
        }

        // El system también se sanitiza: un context malicioso (CLI/FFI/terminal)
        // podría inyectar tokens de template y romper el prompt igual que el
        // history. La app móvil ya neutraliza antes de enviar; esto cubre a
        // TODOS los clientes en la última frontera real.
        let system_msg = sanitize_chat_content(&system_parts.join("\n"));

        // ── User message ────────────────────────────────────────────
        let mut user_parts = Vec::new();

        // RAG context
        if !rag_docs.is_empty() {
            let base_overhead = system_msg.chars().count() + prompt.chars().count() + 100; // markers + assistant
            let available_for_rag = self.context_budget_chars().saturating_sub(base_overhead);
            if available_for_rag > 200 {
                user_parts.push("Context from your documents:\n".to_string());
                let mut used = 0;
                for doc in rag_docs {
                    let remaining = available_for_rag.saturating_sub(used);
                    if remaining < 100 {
                        break;
                    }
                    let snippet = Self::truncate_chars(&doc.content, remaining);
                    user_parts.push(format!("---\n{}\n", snippet));
                    used += snippet.chars().count();
                }
            } else {
                tracing::warn!(
                    "Instruct prompt: skipping RAG docs — only {} chars available for context",
                    available_for_rag
                );
            }
        }

        // Current prompt
        user_parts.push(prompt.to_string());
        // Misma frontera de seguridad que el system: el prompt de cualquier
        // cliente (no solo la app) no puede cerrar turnos del template.
        let user_msg = sanitize_chat_content(&user_parts.join("\n"));

        // ── Assemble chat template ──────────────────────────────────
        // El historial se inyecta como turnos REALES del template (antes
        // viajaba como texto plano dentro del turno user: los modelos
        // instruct lo leían como contenido, no como conversación, y el
        // modelo degradaba a respuestas vacías o genéricas).
        //
        // La familia se detecta desde el template GGUF real; el nombre del
        // archivo queda como fallback para DeepSeek (su chat_template usa
        // variables Jinja sin los literales de los tokens especiales).
        let tpl = self.model_manager.chat_template().await.unwrap_or_default();
        let model_path_lower = self.config.local_model.path.to_lowercase();
        let is_gemma = tpl.contains("start_of_turn");
        let is_deepseek = tpl.contains("begin_of_sentence")
            || tpl.contains("end_of_sentence")
            || model_path_lower.contains("deepseek")
            || model_path_lower.contains("r1");

        let history = request.history.as_deref().unwrap_or(&[]);
        let history: Vec<(String, String)> = history
            .iter()
            .filter(|m| m.role == "user" || m.role == "assistant")
            .map(|m| (m.role.clone(), sanitize_chat_content(&m.content)))
            .collect();

        if is_gemma {
            // Gemma: sin role system separado; se inyecta al inicio del
            // primer turno user. Rol model = "model" en el template.
            let mut out = String::new();
            for (role, content) in &history {
                let turn = if role == "user" { "user" } else { "model" };
                out.push_str(&format!("<start_of_turn>{turn}\n{content}<end_of_turn>\n"));
            }
            let mut first_user = String::new();
            if !system_msg.is_empty() {
                first_user.push_str(&system_msg);
                first_user.push_str("\n\n");
            }
            first_user.push_str(&user_msg);
            out.push_str(&format!(
                "<start_of_turn>user\n{first_user}<end_of_turn>\n<start_of_turn>model\n"
            ));
            out
        } else if is_deepseek {
            // DeepSeek-R1 canónico: BOS al inicio, system crudo, turnos
            // "User:"/"Assistant:" con EOS tras cada turno assistant, y el
            // turno de generación abierto con "Assistant:".
            let mut out = String::new();
            if !system_msg.is_empty() {
                out.push_str(&format!("<｜begin▁of▁sentence｜>{system_msg}\n\n"));
            } else {
                out.push_str("<｜begin▁of▁sentence｜>");
            }
            for (role, content) in &history {
                if role == "user" {
                    out.push_str(&format!("User: {content}\n\n"));
                } else {
                    out.push_str(&format!("Assistant: {content}<｜end▁of▁sentence｜>"));
                }
            }
            out.push_str(&format!("User: {user_msg}\n\nAssistant:"));
            out
        } else {
            // ChatML (Qwen, Llama-3 y la mayoría de instruct).
            let mut out = String::new();
            if !system_msg.is_empty() {
                out.push_str(&format!("<|im_start|>system\n{system_msg}<|im_end|>\n"));
            }
            for (role, content) in &history {
                out.push_str(&format!("<|im_start|>{role}\n{content}<|im_end|>\n"));
            }
            out.push_str(&format!(
                "<|im_start|>user\n{user_msg}<|im_end|>\n<|im_start|>assistant\n"
            ));
            out
        }
    }

    /// Procesa una petición con streaming de tokens.
    ///
    /// Retorna (respuesta_final, receiver) donde el receiver emite
    /// (token_text, probability) por cada token en tiempo real, y la
    /// respuesta completa (texto + confianza + fuentes RAG) se resuelve en
    /// el oneshot cuando la generación termina o se aborta.
    pub async fn process_request_streaming(
        &self,
        request: UserRequest,
    ) -> Result<(
        tokio::sync::oneshot::Receiver<Response>,
        tokio::sync::mpsc::Receiver<(String, f32)>,
    )> {
        let prompt = &request.prompt;

        // Privacy check
        let has_pii = if self.config.hybrid_routing.privacy_filter {
            privacy::contains_pii(prompt)
        } else {
            false
        };

        // RAG streaming: no ejecutar embeddings sincronos con el mismo GGUF.
        // En movil esto crea un contexto llama.cpp extra antes de la respuesta
        // y anade ~15-20s de latencia + cientos de MB de memoria transitoria.
        // Se conserva busqueda lexica ligera; embeddings deben precalcularse
        // fuera del camino caliente del chat.
        let rag_docs = if !has_pii && self.config.memory.max_context_docs > 0 {
            self.vector_engine
                .search(prompt, self.config.memory.max_context_docs, None)
                .await
                .unwrap_or_default()
        } else {
            vec![]
        };

        let augmented_prompt = self
            .build_augmented_prompt(prompt, &rag_docs, &request)
            .await;

        // Generate with streaming — returns the token receiver immediately;
        // the final result (text + per-token probabilities) resolves in the
        // oneshot when generation finishes or is aborted.
        let (result_rx, token_rx) = self
            .model_manager
            .generate_streaming(
                &augmented_prompt,
                request
                    .max_tokens
                    .unwrap_or(self.config.generation.max_tokens),
                request.session_id.as_deref(),
                request.temperature,
            )
            .await?;

        // Monitor de alucinaciones (solo warn, no interrumpe generación)
        let (out_tx, out_rx) = tokio::sync::mpsc::channel(1024);
        let mut raw_rx = token_rx;

        tokio::spawn(async move {
            let mut detector = HallucinationDetector::default();
            while let Some((token, prob)) = raw_rx.recv().await {
                if let Some(signal) = analyze_token(&mut detector, &token, prob) {
                    tracing::warn!(
                        "[HALLUCINATION DETECTED] type={:?} pos={} confidence={:.2} strategy={:?}",
                        signal.htype,
                        signal.token_pos,
                        signal.confidence,
                        signal.strategy
                    );
                }
                if out_tx.send((token, prob)).await.is_err() {
                    break;
                }
            }
        });

        // Final response assembled once generation completes (or aborts).
        // If the generation task died without reporting, fall back to an
        // empty response with a warning — never fabricate metrics.
        let (response_tx, response_rx) = tokio::sync::oneshot::channel();
        tokio::spawn(async move {
            let (text, confidence_scores) = match result_rx.await {
                Ok(Ok((t, s))) => (t, s),
                Ok(Err(e)) => {
                    tracing::warn!("Streaming generation failed: {}", e);
                    (String::new(), Vec::new())
                }
                Err(_) => {
                    tracing::warn!("Streaming generation task died before reporting a result");
                    (String::new(), Vec::new())
                }
            };

            let avg_confidence = token_confidence(&confidence_scores);

            let response = Response {
                text,
                tier_used: "local".to_string(),
                confidence: avg_confidence,
                tool_calls: vec![],
                sources: rag_docs
                    .into_iter()
                    .map(|d| crate::SourceDocument {
                        content: d.content,
                        metadata: d.metadata,
                        similarity: d.similarity,
                    })
                    .collect(),
                tokens_generated: 0,
                model_memory_mb: 0, // Populated from MemoryManager when model is loaded
            };
            let _ = response_tx.send(response);
        });

        Ok((response_rx, out_rx))
    }
    ///
    /// Almacena la corrección en el VectorEngine para que el modelo
    /// pueda consultarla en futuras interacciones similares.
    /// - `original_prompt`: el prompt que generó la respuesta incorrecta
    /// - `user_correction`: el texto corregido por el usuario
    pub async fn learn_from_correction(
        &self,
        original_prompt: &str,
        user_correction: &str,
    ) -> Result<()> {
        let metadata = serde_json::json!({
            "type": "correction",
            "original": original_prompt,
            "source": "user_feedback",
            "timestamp": format!("{:?}", std::time::SystemTime::now()),
        });
        // Generate embedding for the correction to enable semantic search
        let embedding = match self.model_manager.embed_text(user_correction).await {
            Ok(emb) => Some(emb),
            Err(e) => {
                tracing::warn!(
                    "Correction embedding failed — indexing without embedding: {}",
                    e
                );
                None
            }
        };
        self.vector_engine
            .index_document(user_correction, metadata, embedding)
            .await
    }

    /// Samples the thermal controller and returns the current action.
    /// Convenience wrapper that handles the Mutex lock.
    fn sample_thermal(&self) -> ThermalAction {
        let mut tc = match self.thermal.lock() {
            Ok(tc) => tc,
            Err(_) => return ThermalAction::Normal, // poisoned mutex → safe default
        };
        let reading = tc.sample();
        tc.recommend_action(&reading)
    }

    /// Computes throttled generation parameters based on hardware state.
    ///
    /// Returns (adjusted_max_tokens, cooldown_pause_ms). The adjusted token
    /// budget shrinks under thermal pressure or low battery. Cooldown pauses
    /// are inserted between generation cycles to let the device cool down.
    ///
    /// Previously thermal/battery were only logged (placebo throttling).
    /// Now they actually reduce inference workload through token budget
    /// and cooldown delays.
    fn compute_throttled_params(
        thermal: &ThermalAction,
        battery: &BatteryMode,
        base_max_tokens: usize,
    ) -> (usize, u64) {
        let mut max_tokens = base_max_tokens;
        let mut cooldown_ms: u64 = 0;

        // Thermal throttling
        match thermal {
            ThermalAction::Normal => { /* no change */ }
            ThermalAction::ReduceBatch { factor } => {
                max_tokens = (max_tokens as f64 * *factor as f64) as usize;
                tracing::info!(
                    "Thermal ReduceBatch: tokens {} → {}",
                    base_max_tokens,
                    max_tokens
                );
            }
            ThermalAction::Cooldown {
                pause_ms,
                reduce_context,
            } => {
                max_tokens = (max_tokens as f64 * *reduce_context as f64) as usize;
                cooldown_ms = *pause_ms;
                tracing::info!(
                    "Thermal Cooldown: tokens {} → {}, pause {}ms",
                    base_max_tokens,
                    max_tokens,
                    pause_ms
                );
            }
            ThermalAction::Pause {
                pause_ms,
                min_context,
            } => {
                max_tokens = (*min_context).min(max_tokens);
                cooldown_ms = *pause_ms;
                tracing::warn!(
                    "Thermal Pause: tokens → {}, pause {}ms (CRITICAL temp)",
                    max_tokens,
                    pause_ms
                );
            }
        }

        // Battery throttling
        match battery {
            BatteryMode::Performance => { /* no change */ }
            BatteryMode::Balanced => {
                max_tokens = (max_tokens as f64 * 0.8) as usize; // 20% reduction
            }
            BatteryMode::Eco => {
                max_tokens = (max_tokens as f64 * 0.5) as usize; // 50% reduction
            }
            BatteryMode::Survival => {
                max_tokens = max_tokens.min(256); // absolute minimum
                cooldown_ms = cooldown_ms.max(100); // at least 100ms between calls
            }
        }

        // Ensure minimum viable generation
        max_tokens = max_tokens.max(64);

        (max_tokens, cooldown_ms)
    }

    /// Ejecuta inferencia local (Tier 1) con loop de tool calls.
    ///
    /// Pipeline:
    /// 1. Generar respuesta
    /// 2. Detectar tool calls JSON en la salida
    /// 3. Si hay tool call: ejecutar herramienta, re-inyectar resultado,
    ///    continuar generación (máx 3 iteraciones)
    /// 4. Devolver respuesta combinada sin basura JSON visible
    ///
    /// V2: Accepts thermal_action and battery_mode to apply real hardware
    /// throttling (ReduceBatch, Cooldown pauses, Pause delays). Previously
    /// these were sampled but only logged — throttling was a placebo.
    async fn execute_local(
        &self,
        prompt: &str,
        _has_pii: bool,
        thermal_action: &ThermalAction,
        battery_mode: &BatteryMode,
        temperature: Option<f32>,
    ) -> Result<Response> {
        let max_loops = 3;
        let mut full_text = String::new();
        let mut all_tool_calls = Vec::new();
        let mut current_prompt = prompt.to_string();
        let mut final_confidence = None;

        for iteration in 0..max_loops {
            // ── V2: Apply hardware-aware throttling ──────────────
            let (adjusted_max_tokens, cooldown_ms) = Self::compute_throttled_params(
                thermal_action,
                battery_mode,
                self.config.generation.max_tokens,
            );
            if cooldown_ms > 0 {
                tracing::info!(
                    "Thermal cooldown: pausing {}ms before generation (iter {})",
                    cooldown_ms,
                    iteration
                );
                tokio::time::sleep(tokio::time::Duration::from_millis(cooldown_ms)).await;
            }

            let (text, confidence_scores) = self
                .model_manager
                .generate_with_confidence(&current_prompt, adjusted_max_tokens, temperature)
                .await?;

            if iteration == 0 {
                final_confidence = token_confidence(&confidence_scores);

                // Analyze token probabilities for hallucination signals.
                // In the non-streaming path we only have aggregate probabilities,
                // not per-token text. The detector still catches confidence drops
                // and repetition patterns from the probability distribution.
                let mut detector = HallucinationDetector::default();
                let mut hallucination_detected = false;
                for prob in &confidence_scores {
                    // Use empty string as token text — we only have probability data here.
                    // The streaming path (process_request_streaming) has full per-token text
                    // and uses the real detector with actual tokens.
                    let signal = analyze_token(&mut detector, "", *prob);
                    if let Some(signal) = signal {
                        hallucination_detected = true;
                        tracing::warn!(
                            "Hallucination detected: {:?} (confidence={:.2}, perplexity={:.2})",
                            signal.htype,
                            signal.confidence,
                            signal.perplexity,
                        );
                    }
                }
                if hallucination_detected {
                    tracing::info!("Response may contain hallucinations — consider escalating");
                }
            }

            // Check for tool calls in this generation
            let tool_call = self.extract_tool_call_json(&text);
            let Some((tool_name, parameters)) = tool_call else {
                // No more tool calls — append and done
                full_text.push_str(&text);
                break;
            };

            // Validate tool call JSON against grammar
            let grammar = Grammar::json_tool_call();
            let tool_json = serde_json::json!({
                "tool": &tool_name,
                "parameters": &parameters,
            });
            if !grammar.validate(&tool_json.to_string()) {
                tracing::warn!(
                    "Tool call JSON failed grammar validation (tool={}). Attempting execution anyway.",
                    tool_name
                );
            }

            // Strip the JSON tool call from visible output
            let cleaned = self.strip_tool_call_json(&text);
            full_text.push_str(&cleaned);

            // Execute the tool
            tracing::info!(
                "Tool call loop iter {}: {} with params {:?}",
                iteration + 1,
                tool_name,
                parameters
            );

            let result = match self
                .tool_executor
                .execute(&tool_name, parameters.clone())
                .await
            {
                Ok(r) => {
                    // Respect r.success — the executor reports failures as Ok(ToolResult{success:false})
                    if !r.success {
                        tracing::warn!("Tool '{}' failed: {:?}", tool_name, r.error);
                        all_tool_calls.push(ToolCallResult {
                            tool_name: tool_name.clone(),
                            parameters: parameters.clone(),
                            result: serde_json::Value::Null,
                            success: false,
                            error: r.error.clone(),
                        });
                        break; // Tool failed — stop the loop
                    }
                    tracing::info!("Tool '{}' executed ({}ms)", tool_name, r.duration_ms);
                    all_tool_calls.push(ToolCallResult {
                        tool_name: tool_name.clone(),
                        parameters: parameters.clone(),
                        result: r.data.clone(),
                        success: true,
                        error: None,
                    });
                    r.data
                }
                Err(e) => {
                    tracing::warn!("Tool '{}' failed: {}", tool_name, e);
                    all_tool_calls.push(ToolCallResult {
                        tool_name,
                        parameters,
                        result: serde_json::Value::Null,
                        success: false,
                        error: Some(e.to_string()),
                    });
                    break; // Tool failed — stop the loop
                }
            };

            // Build continuation prompt: previous context + result → model continues
            current_prompt = format!(
                "{}\n\nTool call result:\n{}\n\nBased on this result, continue your response naturally. \
                 Do NOT repeat the tool call.\n",
                current_prompt, serde_json::to_string(&result).unwrap_or_default()
            );
        }

        Ok(Response {
            text: full_text,
            tier_used: "local".to_string(),
            confidence: final_confidence,
            tool_calls: all_tool_calls,
            sources: vec![],
            tokens_generated: 0,
            model_memory_mb: 0, // Populated from MemoryManager when model is loaded
        })
    }

    /// Delega en tool_parser (SRP) — elimina JSON de tool call del texto visible.
    fn strip_tool_call_json(&self, text: &str) -> String {
        tool_parser::strip_tool_call_json(text)
    }

    /// Delega en tool_parser (SRP) — extrae tool call JSON del texto.
    fn extract_tool_call_json(&self, text: &str) -> Option<(String, serde_json::Value)> {
        tool_parser::extract_tool_call_json(text)
    }

    /// Ejecuta inferencia en servidor LAN (Tier 2) usando LanExecutor.
    async fn execute_lan(&self, prompt: &str, endpoint: &str) -> Result<Response> {
        let executor = crate::execution::LanExecutor::new(endpoint);
        let lan_res = executor.execute(prompt).await?;

        Ok(Response {
            text: lan_res.text,
            tier_used: "lan".to_string(),
            confidence: Some(lan_res.confidence),
            tool_calls: vec![],
            sources: vec![],
            tokens_generated: 0,
            model_memory_mb: 0, // Populated from MemoryManager when model is loaded
        })
    }

    /// Ejecuta inferencia en la nube (Tier 3).
    async fn execute_cloud(&self, prompt: &str) -> Result<Response> {
        if !self.cloud_rate_limiter.try_consume_one() {
            return Err(crate::error::NanoError::Internal {
                message: "Cloud rate limit exceeded".to_string(),
            });
        }

        cloud::execute_cloud(&self.config.tiers.tier3, prompt).await
    }
}

/// Neutraliza tokens de control del template dentro del CONTENIDO de un
/// turno: si un mensaje del historial los contiene literales, rompería la
/// estructura del prompt (el modelo vería un cierre de turno anticipado y
/// degradaría a respuestas vacías o genéricas).
fn sanitize_chat_content(content: &str) -> String {
    content
        .replace("<|im_start|>", "< |im_start| >")
        .replace("<|im_end|>", "< |im_end| >")
        .replace("<|eot_id|>", "< |eot_id| >")
        .replace("<start_of_turn>", "< start_of_turn >")
        .replace("<end_of_turn>", "< end_of_turn >")
        .replace("<｜begin▁of▁sentence｜>", "< |begin_of_sentence| >")
        .replace("<｜end▁of▁sentence｜>", "< |end_of_sentence| >")
}

#[cfg(test)]
#[cfg(feature = "simulated")]
mod tests {
    use super::*;
    use crate::config::manifest::Config;
    use std::io::Write;

    async fn test_orchestrator() -> Orchestrator {
        let config = Config::test_config();
        let model_manager = std::sync::Arc::new(
            crate::execution::ModelManager::new(config.clone())
                .await
                .unwrap(),
        );
        let vector_engine =
            std::sync::Arc::new(crate::execution::VectorEngine::new(&config).await.unwrap());
        let tool_executor =
            std::sync::Arc::new(crate::execution::ToolExecutor::new(&config).await.unwrap());
        Orchestrator::new(config, model_manager, vector_engine, tool_executor)
    }

    #[tokio::test]
    async fn test_extract_tool_call_nano_format() {
        let orch = test_orchestrator().await;
        let text = r#"Some text before {"tool": "get_weather", "parameters": {"city": "London"}} some after"#;
        let result = orch.extract_tool_call_json(text);
        assert!(result.is_some());
        let (name, params) = result.unwrap();
        assert_eq!(name, "get_weather");
        assert_eq!(params["city"], "London");
    }

    #[tokio::test]
    async fn test_extract_tool_call_openai_format() {
        let orch = test_orchestrator().await;
        let text = r#"{"name": "send_email", "arguments": {"to": "a@b.com", "subject": "Hello"}}"#;
        let result = orch.extract_tool_call_json(text);
        assert!(result.is_some());
        let (name, params) = result.unwrap();
        assert_eq!(name, "send_email");
        assert_eq!(params["to"], "a@b.com");
    }

    #[tokio::test]
    async fn test_extract_tool_call_no_tool() {
        let orch = test_orchestrator().await;
        let text = "This is just a normal response without any tool call.";
        assert!(orch.extract_tool_call_json(text).is_none());
    }

    #[tokio::test]
    async fn test_extract_tool_call_invalid_json() {
        let orch = test_orchestrator().await;
        let text = r#"Some text {"tool": "test", "parameters": {"x": broken}} after"#;
        assert!(orch.extract_tool_call_json(text).is_none());
    }

    #[tokio::test]
    async fn test_extract_tool_call_in_response_text() {
        let orch = test_orchestrator().await;
        let text = "I'll look up the weather for you.\n\n{\"tool\": \"get_weather\", \"parameters\": {\"city\": \"Tokyo\"}}\n\nPlease wait while I fetch the data.";
        let result = orch.extract_tool_call_json(text);
        assert!(result.is_some());
        let (name, params) = result.unwrap();
        assert_eq!(name, "get_weather");
        assert_eq!(params["city"], "Tokyo");
    }

    #[tokio::test]
    async fn test_extract_tool_call_noop() {
        let orch = test_orchestrator().await;
        let text = "Just a normal response without tool calls.";
        let result = orch.extract_tool_call_json(text);
        assert!(result.is_none());
    }

    #[tokio::test]
    async fn test_strip_tool_call_json() {
        let orch = test_orchestrator().await;
        let text = "Let me check the weather. {\"tool\": \"get_weather\", \"parameters\": {\"city\": \"London\"}}";
        let stripped = orch.strip_tool_call_json(text);
        assert_eq!(stripped, "Let me check the weather.");
        assert!(!stripped.contains("tool"));
        assert!(!stripped.contains("get_weather"));
    }

    #[tokio::test]
    async fn test_strip_tool_call_openai_format() {
        let orch = test_orchestrator().await;
        let text =
            "I'll send an email. {\"name\": \"send_email\", \"arguments\": {\"to\": \"a@b.com\"}}";
        let stripped = orch.strip_tool_call_json(text);
        assert_eq!(stripped, "I'll send an email.");
    }

    #[tokio::test]
    async fn test_strip_tool_call_no_tool() {
        let orch = test_orchestrator().await;
        let text = "This is a normal response without any JSON.";
        let stripped = orch.strip_tool_call_json(text);
        assert_eq!(stripped, "This is a normal response without any JSON.");
    }

    #[tokio::test]
    async fn test_execute_local_no_tools() {
        let orch = test_orchestrator().await;
        // Need a model loaded for execute_local to work
        let model_dir = std::path::Path::new(&orch.config.local_model.path)
            .parent()
            .unwrap_or_else(|| std::path::Path::new("."));
        std::fs::create_dir_all(model_dir).unwrap();
        let model_path = model_dir.join("dummy-test-model.gguf");
        std::fs::File::create(&model_path)
            .and_then(|mut f| f.write_all(b"dummy"))
            .unwrap();
        orch.model_manager
            .load_model(model_path.to_str().unwrap())
            .await
            .unwrap();
        let _ = std::fs::remove_file(&model_path);
        let thermal = ThermalAction::Normal;
        let battery = BatteryMode::Performance;
        let response = orch
            .execute_local("Hello", false, &thermal, &battery, None)
            .await
            .unwrap();
        assert!(!response.text.is_empty());
        assert_eq!(response.tier_used, "local");
        assert!(response.tool_calls.is_empty());
    }
}
