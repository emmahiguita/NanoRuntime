//! Capa de orquestación — routing híbrido, privacidad y confianza.
//!
//! El orchestrator decide si una petición se procesa localmente (Tier 1),
//! en un servidor LAN (Tier 2) o en la nube (Tier 3). La decisión se basa
//! en detección de PII, entropía de la respuesta local y configuración.

pub mod confidence;
pub mod privacy;
pub mod router;

use std::sync::Arc;

use crate::config::manifest::Config;
use crate::error::Result;
use crate::execution::{ModelManager, PromptCache, RateLimiter, ToolExecutor, VectorEngine};
use crate::inference::grammar::Grammar;
use crate::inference::research::hallucination_detector::{HallucinationDetector, analyze_token};
use crate::{Response, ToolCallResult, UserRequest};

// ── V2: Policy Engine + Cost Scheduler ─────────────────────────────
use crate::memory_engine::policy_engine::{PolicyEngine, QosMode};
use crate::memory_engine::cost_scheduler::CostScheduler;
use crate::memory_engine::hardware_hal::profile_device;
use crate::speculative_decoder::{SpeculativePlan, InferenceMode};

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
        Self {
            config,
            model_manager,
            vector_engine,
            tool_executor,
            router,
            prompt_cache,
            cloud_rate_limiter,
            lan_rate_limiter,
        }
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
            plan.mode, profile.ram_available_mb, target_size_mb, draft_size_mb
        );
        plan.mode
    }

    /// Procesa una petición completa del usuario a través del pipeline.
    ///
    /// Pipeline:
    /// 1. Privacy check — detecta PII y fuerza Tier 1 si es necesario
    /// 2. RAG — busca documentos relevantes para enriquecer el contexto
    /// 3. Prompt cache — salta generación si el prompt exacto ya se respondió
    /// 4. Local inference — genera respuesta local primero
    /// 5. Tool detection — escanea la salida en busca de tool calls JSON
    /// 6. Confidence check — si confianza baja y cloud habilitado, escala a cloud
    /// 7. Rate limiter — verifica límites antes de llamadas cloud/LAN
    pub async fn process_request(
        &self,
        request: UserRequest,
    ) -> Result<Response> {
        let prompt = &request.prompt;

        // Step 1: Privacy check
        let has_pii = if self.config.hybrid_routing.privacy_filter {
            privacy::contains_pii(prompt)
        } else {
            false
        };

        // Step 2: RAG — search for relevant documents using embeddings
        let rag_docs = if !has_pii {
            // Try semantic search with embeddings from the model
            let query_embedding = self.model_manager.embed_text(prompt).await.ok();
            self.vector_engine
                .search(prompt, self.config.memory.max_context_docs, query_embedding.as_deref())
                .await
                .unwrap_or_default()
        } else {
            vec![]
        };

        // Step 3: Build augmented context
        let augmented_prompt = self.build_augmented_prompt(prompt, &rag_docs, &request).await;

        // Step 4: Check prompt cache (only if no tools that might change output)
        if self.config.hybrid_routing.enabled && self.tool_executor.list_tools().await.is_empty() {
            let mut cache = self.prompt_cache.lock().await;
            if let Some((cached_text, cached_probs)) = cache.get(&augmented_prompt) {
                let avg_confidence = if !cached_probs.is_empty() {
                    Some((cached_probs.iter().sum::<f32>() / cached_probs.len() as f32).clamp(0.01, 0.99))
                } else {
                    None
                };
                tracing::debug!("Prompt cache HIT, returning cached response");
                return Ok(Response {
                    text: cached_text,
                    tier_used: "local (cached)".to_string(),
                    confidence: avg_confidence,
                    tool_calls: vec![],
                    sources: vec![],
                    tokens_generated: 0,
                });
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
        let response = match routing_decision {
            router::RoutingDecision::Local => {
                self.execute_local_with_escalation(&augmented_prompt, has_pii).await
            }
            router::RoutingDecision::Cloud(anonymized) => {
                // Check cloud rate limiter
                if !self.cloud_rate_limiter.try_consume_one() {
                    tracing::warn!("Cloud rate limit exceeded, falling back to local");
                    self.execute_local_with_escalation(&augmented_prompt, has_pii).await
                } else {
                    // Try cloud; if it fails, fall back to local
                    match self.execute_cloud(&anonymized).await {
                        Ok(response) => Ok(response),
                        Err(e) => {
                            tracing::warn!("Cloud execution failed ({}), falling back to local", e);
                            self.execute_local_with_escalation(&augmented_prompt, has_pii).await
                        }
                    }
                }
            }
            router::RoutingDecision::Lan(endpoint) => {
                // Check LAN rate limiter
                if !self.lan_rate_limiter.try_consume_one() {
                    tracing::warn!("LAN rate limit exceeded, falling back to local");
                    self.execute_local_with_escalation(&augmented_prompt, has_pii).await
                } else {
                    // Try LAN; if it fails, fall back to local
                    match self.execute_lan(&augmented_prompt, &endpoint).await {
                        Ok(response) => Ok(response),
                        Err(e) => {
                            tracing::warn!("LAN execution failed ({}), falling back to local", e);
                            self.execute_local_with_escalation(&augmented_prompt, has_pii).await
                        }
                    }
                }
            }
        }?;

        // Step 7: Store in prompt cache (only local responses without tool calls)
        if self.config.hybrid_routing.enabled
            && self.tool_executor.list_tools().await.is_empty()
            && response.tier_used.starts_with("local")
            && response.tool_calls.is_empty()
        {
            let mut cache = self.prompt_cache.lock().await;
            cache.put(&augmented_prompt, response.text.clone(), vec![]);
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
    ) -> Result<Response> {
        // Step 1: Always try local first
        let local = self.execute_local(prompt, has_pii).await?;

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
                    avg_confidence, threshold
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
                avg_confidence, threshold
            );
        }

        Ok(local)
    }

    /// Construye el prompt aumentado con documentos RAG, historial y herramientas.
    async fn build_augmented_prompt(
        &self,
        prompt: &str,
        rag_docs: &[crate::SourceDocument],
        request: &UserRequest,
    ) -> String {
        let mut parts = Vec::new();

        // System prompt with tools
        let tools_prompt = self.tool_executor.build_system_prompt().await;
        if !tools_prompt.is_empty() {
            parts.push(tools_prompt);
        }

        // Learned corrections (from user feedback)
        let corrections = self.vector_engine.search(
            prompt,
            self.config.memory.max_context_docs.min(3),
            None,
        ).await.unwrap_or_default();
        let corrections: Vec<&crate::SourceDocument> = corrections.iter()
            .filter(|d| d.metadata.get("type").and_then(|v| v.as_str()) == Some("correction"))
            .collect();
        if !corrections.is_empty() {
            parts.push("Previously learned corrections:\n".to_string());
            for corr in corrections {
                let original = corr.metadata.get("original").and_then(|v| v.as_str()).unwrap_or("");
                let correction = &corr.content;
                parts.push(format!("- User corrected: '{}' → '{}'", original, correction));
            }
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

        parts.join("\n")
    }

    /// Procesa una petición con streaming de tokens.
    ///
    /// Retorna un receiver que emite (token_text, probability) por cada token.
    /// El primer mensaje es la respuesta completa al final.
    pub async fn process_request_streaming(
        &self,
        request: UserRequest,
    ) -> Result<(Response, tokio::sync::mpsc::Receiver<(String, f32)>)> {
        let prompt = &request.prompt;

        // Privacy check
        let has_pii = if self.config.hybrid_routing.privacy_filter {
            privacy::contains_pii(prompt)
        } else {
            false
        };

        // RAG
        let rag_docs = if !has_pii {
            let query_embedding = self.model_manager.embed_text(prompt).await.ok();
            self.vector_engine
                .search(prompt, self.config.memory.max_context_docs, query_embedding.as_deref())
                .await
                .unwrap_or_default()
        } else {
            vec![]
        };

        let augmented_prompt = self.build_augmented_prompt(prompt, &rag_docs, &request).await;

        // Generate with streaming
        let (text, confidence_scores, token_rx) = self
            .model_manager
            .generate_streaming(&augmented_prompt, self.config.generation.max_tokens)
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
                        signal.htype, signal.token_pos, signal.confidence, signal.strategy
                    );
                }
                if out_tx.send((token, prob)).await.is_err() {
                    break;
                }
            }
        });

        let avg_confidence = if !confidence_scores.is_empty() {
            // Average token probability as confidence (0.0-1.0)
            // Avoids negative values from misapplied entropy formula
            let avg: f32 = confidence_scores.iter().sum::<f32>() / confidence_scores.len() as f32;
            Some(avg.clamp(0.01, 0.99))
        } else {
            None
        };

        let response = Response {
            text,
            tier_used: "local".to_string(),
            confidence: avg_confidence,
            tool_calls: vec![],
            sources: rag_docs.into_iter().map(|d| crate::SourceDocument {
                content: d.content,
                metadata: d.metadata,
                similarity: d.similarity,
            }).collect(),
            tokens_generated: 0,
        };

        Ok((response, out_rx))
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
        let embedding = self.model_manager.embed_text(user_correction).await.ok();
        self.vector_engine.index_document(user_correction, metadata, embedding).await
    }

    /// Ejecuta inferencia local (Tier 1) con loop de tool calls.
    ///
    /// Pipeline:
    /// 1. Generar respuesta
    /// 2. Detectar tool calls JSON en la salida
    /// 3. Si hay tool call: ejecutar herramienta, re-inyectar resultado,
    ///    continuar generación (máx 3 iteraciones)
    /// 4. Devolver respuesta combinada sin basura JSON visible
    async fn execute_local(
        &self,
        prompt: &str,
        _has_pii: bool,
    ) -> Result<Response> {
        let max_loops = 3;
        let mut full_text = String::new();
        let mut all_tool_calls = Vec::new();
        let mut current_prompt = prompt.to_string();
        let mut final_confidence = None;

        for iteration in 0..max_loops {
            let (text, confidence_scores) = self
                .model_manager
                .generate_with_confidence(&current_prompt, self.config.generation.max_tokens)
                .await?;

            if iteration == 0 {
                final_confidence = if !confidence_scores.is_empty() {
                    Some((confidence_scores.iter().sum::<f32>() / confidence_scores.len() as f32).clamp(0.01, 0.99))
                } else {
                    None
                };

                // Analyze tokens for hallucination signals
                let mut detector = HallucinationDetector::default();
                let mut hallucination_detected = false;
                // Use token probabilities as signal (approximation without per-token text)
                for prob in &confidence_scores {
                    let dummy_token = if *prob < 0.2 { "[low_prob]" } else { "[tok]" };
                    let signal = analyze_token(&mut detector, dummy_token, *prob);
                    if signal.is_some() {
                        hallucination_detected = true;
                        tracing::warn!(
                            "Hallucination detected: {:?} (confidence={:.2}, perplexity={:.2})",
                            signal.as_ref().unwrap().htype,
                            signal.as_ref().unwrap().confidence,
                            signal.as_ref().unwrap().perplexity,
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
                iteration + 1, tool_name, parameters
            );

            let result = match self.tool_executor.execute(&tool_name, parameters.clone()).await {
                Ok(r) => {
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
        })
    }

    /// Elimina el JSON de tool call del texto visible.
    ///
    /// El modelo podría generar algo como:
    /// "Let me check the weather. {"tool": "get_weather", "parameters": {"city": "London"}}"
    ///
    /// Esto devuelve solo: "Let me check the weather."
    ///
    /// Soporta ambos formatos: NanoAI (tool/parameters) y OpenAI (name/arguments).
    fn strip_tool_call_json(&self, text: &str) -> String {
        let mut result = text.to_string();

        // Pattern 1: {"tool": "...", "parameters": {...}}
        if let Some(start) = result.find("\"tool\"") {
            if let Some(brace_start) = result[..start].rfind('{') {
                if let Some(end) = self.find_matching_brace(&result[brace_start..]) {
                    let before = &result[..brace_start];
                    let after = &result[brace_start + end..];
                    result = format!("{}{}", before.trim_end(), after);
                }
            }
        }

        // Pattern 2: {"name": "...", "arguments": {...}} (OpenAI format)
        if let Some(start) = result.find("\"name\"") {
            if result.contains("\"arguments\"") {
                if let Some(brace_start) = result[..start].rfind('{') {
                    if let Some(end) = self.find_matching_brace(&result[brace_start..]) {
                        let before = &result[..brace_start];
                        let after = &result[brace_start + end..];
                        result = format!("{}{}", before.trim_end(), after);
                    }
                }
            }
        }

        result.trim().to_string()
    }

    /// Encuentra el brace de cierre correspondiente al brace de apertura.
    fn find_matching_brace(&self, s: &str) -> Option<usize> {
        let mut depth = 0;
        for (i, ch) in s.char_indices() {
            match ch {
                '{' => depth += 1,
                '}' => {
                    depth -= 1;
                    if depth == 0 {
                        return Some(i + 1);
                    }
                }
                _ => {}
            }
        }
        None
    }

    /// Extrae un tool call JSON del texto generado.
    ///
    /// Busca el primer patrón que coincida con:
    ///   `{"tool": "name", "parameters": {...}}` o
    ///   `{"name": "name", "arguments": {...}}`
    /// y retorna (tool_name, parameters) si encuentra uno válido.
    fn extract_tool_call_json(&self, text: &str) -> Option<(String, serde_json::Value)> {
        // Pattern 1: {"tool": "...", "parameters": {...}}
        if let Some(result) = self.try_parse_tool_format(text) {
            return Some(result);
        }
        // Pattern 2: {"name": "...", "arguments": {...}} (OpenAI/Anthropic format)
        if let Some(result) = self.try_parse_function_format(text) {
            return Some(result);
        }
        None
    }

    /// Intenta parsear el formato {"tool": "...", "parameters": {...}}.
    fn try_parse_tool_format(&self, text: &str) -> Option<(String, serde_json::Value)> {
        let start = text.find("\"tool\"")?;

        // Find the enclosing braces
        let brace_start = text[..start].rfind('{')?;
        let after_tool = &text[start..];

        // Find matching closing brace
        let mut depth = 0;
        let mut end = 0;
        for (i, ch) in after_tool.char_indices() {
            if ch == '{' { depth += 1; }
            else if ch == '}' { depth -= 1; }
            if depth < 0 && ch == '}' {
                end = i + 1;
                break;
            }
        }
        if end == 0 { return None; }

        let json_str = &text[brace_start..start + end];
        let parsed: serde_json::Value = serde_json::from_str(json_str).ok()?;

        let tool_name = parsed.get("tool")?.as_str()?.to_string();
        let parameters = parsed.get("parameters")?.clone();
        Some((tool_name, parameters))
    }

    /// Intenta parsear el formato {"name": "...", "arguments": {...}}.
    fn try_parse_function_format(&self, text: &str) -> Option<(String, serde_json::Value)> {
        let start = text.find("\"name\"")?;

        // Must also contain "arguments"
        if !text.contains("\"arguments\"") {
            return None;
        }

        let brace_start = text[..start].rfind('{')?;
        let after_name = &text[start..];

        let mut depth = 0;
        let mut end = 0;
        for (i, ch) in after_name.char_indices() {
            if ch == '{' { depth += 1; }
            else if ch == '}' { depth -= 1; }
            if depth < 0 && ch == '}' {
                end = i + 1;
                break;
            }
        }
        if end == 0 { return None; }

        let json_str = &text[brace_start..start + end];
        let parsed: serde_json::Value = serde_json::from_str(json_str).ok()?;

        let tool_name = parsed.get("name")?.as_str()?.to_string();
        let parameters = parsed.get("arguments")?.clone();
        Some((tool_name, parameters))
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
        })
    }

    /// Ejecuta inferencia en la nube (Tier 3).
    async fn execute_cloud(&self, prompt: &str) -> Result<Response> {
        let tier3 = &self.config.tiers.tier3;
        let api_key = std::env::var(&tier3.api_key_env).map_err(|_| {
            crate::error::NanoError::ConfigError {
                reason: format!(
                    "Tier 3 API key not found in env var '{}'",
                    tier3.api_key_env
                ),
            }
        })?;

        let client = reqwest::Client::new();

        let response_text = match tier3.provider.as_str() {
            "anthropic" => {
                let resp = client
                    .post("https://api.anthropic.com/v1/messages")
                    .header("x-api-key", &api_key)
                    .header("anthropic-version", "2023-06-01")
                    .header("Content-Type", "application/json")
                    .json(&serde_json::json!({
                        "model": tier3.model,
                        "max_tokens": tier3.max_tokens,
                        "messages": [{
                            "role": "user",
                            "content": prompt
                        }]
                    }))
                    .send()
                    .await?;

                let status = resp.status();
                let body: serde_json::Value = resp.json().await?;
                if !status.is_success() {
                    return Err(crate::error::NanoError::Internal {
                        message: format!("Anthropic API error ({}): {}", status, body),
                    });
                }
                body["content"][0]["text"]
                    .as_str()
                    .unwrap_or("")
                    .to_string()
            }
            "google" | "gemini" => {
                let model = if tier3.model.is_empty() {
                    "gemini-2.0-flash"
                } else {
                    &tier3.model
                };
                let url = format!(
                    "https://generativelanguage.googleapis.com/v1/models/{}:generateContent?key={}",
                    model, api_key
                );
                let resp = client
                    .post(&url)
                    .header("Content-Type", "application/json")
                    .json(&serde_json::json!({
                        "contents": [{
                            "parts": [{"text": prompt}]
                        }],
                        "generationConfig": {
                            "maxOutputTokens": tier3.max_tokens,
                            "temperature": tier3.temperature
                        }
                    }))
                    .send()
                    .await?;

                let status = resp.status();
                let body: serde_json::Value = resp.json().await?;
                if !status.is_success() {
                    return Err(crate::error::NanoError::Internal {
                        message: format!("Gemini API error ({}): {}", status, body),
                    });
                }
                body["candidates"][0]["content"]["parts"][0]["text"]
                    .as_str()
                    .unwrap_or("")
                    .to_string()
            }
            "openai" => {
                let resp = client
                    .post("https://api.openai.com/v1/chat/completions")
                    .header("Authorization", format!("Bearer {}", api_key))
                    .header("Content-Type", "application/json")
                    .json(&serde_json::json!({
                        "model": tier3.model,
                        "max_tokens": tier3.max_tokens,
                        "messages": [{
                            "role": "user",
                            "content": prompt
                        }]
                    }))
                    .send()
                    .await?;

                let status = resp.status();
                let body: serde_json::Value = resp.json().await?;
                if !status.is_success() {
                    return Err(crate::error::NanoError::Internal {
                        message: format!("OpenAI API error ({}): {}", status, body),
                    });
                }
                body["choices"][0]["message"]["content"]
                    .as_str()
                    .unwrap_or("")
                    .to_string()
            }
            _ => {
                return Err(crate::error::NanoError::ConfigError {
                    reason: format!("Unknown Tier 3 provider: {}", tier3.provider),
                });
            }
        };

        Ok(Response {
            text: response_text,
            tier_used: "cloud".to_string(),
            confidence: None,
            tool_calls: vec![],
            sources: vec![],
            tokens_generated: 0,
        })
    }
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
            crate::execution::ModelManager::new(config.clone()).await.unwrap()
        );
        let vector_engine = std::sync::Arc::new(
            crate::execution::VectorEngine::new(&config).await.unwrap()
        );
        let tool_executor = std::sync::Arc::new(
            crate::execution::ToolExecutor::new(&config).await.unwrap()
        );
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
        let text = "I'll send an email. {\"name\": \"send_email\", \"arguments\": {\"to\": \"a@b.com\"}}";
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
        let dir = tempfile::tempdir().unwrap();
        let model_path = dir.path().join("dummy.gguf");
        std::fs::File::create(&model_path)
            .and_then(|mut f| f.write_all(b"dummy"))
            .unwrap();
        orch.model_manager.load_model(model_path.to_str().unwrap()).await.unwrap();
        let response = orch.execute_local("Hello", false).await.unwrap();
        assert!(!response.text.is_empty());
        assert_eq!(response.tier_used, "local");
        assert!(response.tool_calls.is_empty());
    }
}
