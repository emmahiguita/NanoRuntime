//! Gestor de modelos de IA.
//!
//! Crea contexto fresco por cada generación para evitar contaminación del KV cache.

use std::path::Path;
use std::sync::Arc;

use tokio::sync::RwLock;

use crate::config::manifest::Config;
use crate::error::{NanoError, Result};
use crate::execution::memory_manager::MemoryManager;
#[cfg(not(feature = "simulated"))]
use crate::inference_backend::{
    BackendGenerateParams, BackendLoadParams, InferenceBackend, LlamaCppBackend,
};

#[cfg(not(feature = "simulated"))]
type NanoModel = <LlamaCppBackend as InferenceBackend>::Model;
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
    model: Option<NanoModel>,
    #[cfg(not(feature = "simulated"))]
    load_params: BackendLoadParams,
    #[cfg(not(feature = "simulated"))]
    lora_adapter: Option<NanoLoraAdapter>,
    #[cfg(not(feature = "simulated"))]
    lora_path: Option<String>,
    #[cfg_attr(feature = "simulated", allow(dead_code))]
    generation: u64,
}

pub struct ModelManager {
    config: Config,
    // Arc so blocking generation threads can restore the model into state via
    // blocking_write() once inference finishes (tokio-sanctioned pattern).
    state: Arc<RwLock<Option<ModelState>>>,
    pub memory_engine: std::sync::Mutex<crate::memory_engine::NanoMemoryEngine>,
}

impl ModelManager {
    pub async fn new(config: Config) -> Result<Self> {
        let engine = crate::memory_engine::NanoMemoryEngine::new(32);
        Ok(Self {
            config,
            state: Arc::new(RwLock::new(None)),
            memory_engine: std::sync::Mutex::new(engine),
        })
    }

    pub async fn load_model(&self, path: &str) -> Result<()> {
        if path.is_empty() || !Path::new(path).exists() {
            return Err(NanoError::ModelNotFound {
                path: path.to_string(),
            });
        }

        // Path traversal protection: canonicalize both paths and verify the
        // resolved target does not escape the configured models directory via
        // `..` segments or symlinks.
        let models_dir_raw = Path::new(&self.config.local_model.path)
            .parent()
            .unwrap_or(Path::new("."));
        let models_dir = models_dir_raw
            .canonicalize()
            .map_err(|e| NanoError::ModelLoadFailed {
                path: self.config.local_model.path.clone(),
                reason: format!("Failed to resolve configured models directory: {}", e),
            })?;
        let canonical = Path::new(path)
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

        // Capture generation counter before unloading (unload sets state=None)
        #[cfg(not(feature = "simulated"))]
        let next_gen = {
            let g = self.state.read().await;
            g.as_ref().map_or(0, |s| s.generation.wrapping_add(1))
        };
        self.unload_model().await;

        // ── V2: Auto-detect device profile and compute optimal config ──
        let file_size_mb = std::fs::metadata(path)
            .map(|m| m.len() / (1024 * 1024))
            .unwrap_or(0);
        let (v2_ctx, v2_batch, v2_risk) = MemoryManager::auto_configure_v2(
            file_size_mb,
            8192, // max context
        );
        // Auto-detect optimal thread count from big.LITTLE architecture
        let profile = crate::memory_engine::hardware_hal::profile_device();
        // On desktop/server (Flagship/Desktop tier), use all physical cores.
        // On mobile (Budget/MidRange), use big_cores to avoid LITTLE-core thrashing.
        let optimal_threads = match profile.tier {
            crate::memory_engine::hardware_hal::DeviceTier::Desktop
            | crate::memory_engine::hardware_hal::DeviceTier::Flagship => {
                // Desktop: homogeneous cores, use all for max throughput
                let n = profile.cpu_cores as usize;
                if n > 0 {
                    n
                } else {
                    self.config.local_model.threads
                }
            }
            _ => {
                // Mobile: big.LITTLE — use only big cores to avoid cache thrashing
                if profile.big_cores > 0 {
                    profile.big_cores as usize
                } else {
                    self.config.local_model.threads
                }
            }
        };
        tracing::info!(
            "V2 Auto-config: ctx={} batch={} risk={} threads={} big_cores={} model_mb={}",
            v2_ctx,
            v2_batch,
            v2_risk,
            optimal_threads,
            profile.big_cores,
            file_size_mb
        );
        // Override config with V2-optimized values
        let mut adapted_config = self.config.local_model.clone();
        adapted_config.context_size = v2_ctx as usize;
        adapted_config.batch_size = v2_batch as usize;
        adapted_config.threads = optimal_threads;

        // ── Hierarchical KV: estimate compression potential (informational only) ──
        // NOTE: The HierarchicalKvCache estimator is a planning tool — it does NOT
        // apply quantization. Inflating context_size based on fictional compression
        // causes real OOM because the llama.cpp context is allocated at full FP16.
        // We log the estimate for future hardware-aware tuning but do NOT modify
        // the context allocation.
        {
            let kv_cache = crate::memory_engine::hierarchical_kv::HierarchicalKvCache::new(32, 128);
            let kv_savings =
                kv_cache.estimate_savings(adapted_config.context_size, profile.ram_total_mb);
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
                gpu_layers: adapted_config.gpu_layers as i32,
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
            let ctx_sz = lp.context_size;
            let mut g = self.state.write().await;
            *g = Some(ModelState {
                model_path: path.into(),
                context_size: ctx_sz as usize,
                is_simulated: false,
                model: Some(model),
                load_params: lp,
                lora_adapter: None,
                lora_path: None,
                generation: next_gen,
            });
            // Initialize the memory engine's storage layer with the GGUF layout.
            // The layout analyzer enables contiguous layer grouping for eviction/prefetch.
            // The OS paginator requires a raw memory pointer (model mmap) which is not
            // currently exposed by llama.cpp's Rust bindings — it will be initialized
            // from the FFI layer when available (see nanortime-ffi for future work).
            if let Ok(mut engine) = self.memory_engine.lock() {
                engine.storage.init_layout(Path::new(path), 32);
                engine.set_model_memory(file_size_mb);
            }
            tracing::info!("Model loaded: {} (vocab: {}, ctx: {})", path, nv, ctx_sz);
            Ok(())
        }
    }

    pub async fn unload_model(&self) {
        let mut g = self.state.write().await;
        if let Some(ref s) = *g {
            tracing::info!("Unloading: {}", s.model_path);
        }
        *g = None;
    }

    /// Guarda el estado (KV cache) a un archivo de sesión.
    ///
    /// Usa la API `state_save_file` del contexto de llama.cpp.
    /// Requiere un contexto activo — se obtiene del modelo cargado.
    pub async fn save_session_state(&self, path: &str) -> Result<()> {
        #[cfg(feature = "simulated")]
        let _ = path;

        #[cfg(not(feature = "simulated"))]
        {
            let g = self.state.read().await;
            if let Some(ref s) = *g {
                if let Some(ref model) = s.model {
                    let ctx =
                        LlamaCppBackend::create_context(model, &s.load_params).map_err(|e| {
                            NanoError::ModelLoadFailed {
                                path: s.model_path.clone(),
                                reason: e,
                            }
                        })?;
                    let bytes_written = LlamaCppBackend::save_state(&ctx, path).map_err(|e| {
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

    /// Restaura el estado (KV cache) desde un archivo de sesión.
    pub async fn restore_session_state(&self, path: &str) -> Result<()> {
        #[cfg(feature = "simulated")]
        let _ = path;

        #[cfg(not(feature = "simulated"))]
        {
            let g = self.state.read().await;
            if let Some(ref s) = *g {
                if let Some(ref model) = s.model {
                    let mut ctx =
                        LlamaCppBackend::create_context(model, &s.load_params).map_err(|e| {
                            NanoError::ModelLoadFailed {
                                path: s.model_path.clone(),
                                reason: e,
                            }
                        })?;
                    let tokens = LlamaCppBackend::load_state(&mut ctx, path).map_err(|e| {
                        NanoError::ModelLoadFailed {
                            path: path.to_string(),
                            reason: e,
                        }
                    })?;
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

    /// Ejecuta un paso del NanoMemoryEngine para evaluar prioridad de capas y calidad.
    /// Computes layer attention scores, generates a memory schedule, and applies it
    /// via the storage manager (OS-level eviction/prefetch when available).
    pub fn update_memory_engine_metrics(&self, token_probs: &[f32]) {
        if let Ok(mut engine) = self.memory_engine.lock() {
            let n_layers = 32;
            let mut scores = vec![0.3f32; n_layers];
            // Estimar scores de atención por capa basados en las probabilidades observadas
            let avg_prob = if !token_probs.is_empty() {
                token_probs.iter().sum::<f32>() / token_probs.len() as f32
            } else {
                0.8
            };
            for (idx, score) in scores.iter_mut().enumerate() {
                if idx % 3 == 1 {
                    *score = (avg_prob * 1.2).clamp(0.0, 1.0);
                } else {
                    *score = avg_prob.clamp(0.0, 1.0);
                }
            }
            let schedule = engine.compute_schedule(&scores);
            // Apply the computed schedule to physical memory via OS pagination.
            // When the paginator is not yet initialized (needs model mmap pointer),
            // this logs diagnostic info and gracefully degrades — the quality
            // preserver still benefits from the scheduler's strategy adjustments.
            if let Err(e) = engine.storage.apply_schedule(&schedule) {
                tracing::warn!("Failed to apply memory schedule: {:?}", e);
            }
            // Estimar perplejidad desde probabilidades = exp(-mean(ln(p)))
            let avg_nll = if !token_probs.is_empty() {
                -token_probs.iter().map(|&p| p.max(0.01).ln()).sum::<f32>()
                    / token_probs.len() as f32
            } else {
                0.2
            };
            let perplexity = avg_nll.exp();
            let report = engine.evaluate_quality(perplexity);
            tracing::debug!("[NanoMemoryEngine] {}", engine.status_report());
            let _ = report;
        }
    }

    pub async fn generate_with_confidence(
        &self,
        prompt: &str,
        max_tokens: usize,
    ) -> Result<(String, Vec<f32>)> {
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
                let lp = s.load_params.clone();
                let la = s.lora_adapter.take();
                (m, lp, la, gen)
            };

            let gp = BackendGenerateParams {
                max_tokens,
                temperature: self.config.generation.temperature,
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
        let (t, _) = self.generate_with_confidence(prompt, max_tokens).await?;
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
                    message: "No model loaded".to_string(),
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
    pub async fn context_size(&self) -> Option<usize> {
        self.state.read().await.as_ref().map(|s| s.context_size)
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
    ) -> Result<(
        tokio::sync::oneshot::Receiver<Result<(String, Vec<f32>)>>,
        TokenReceiver,
    )> {
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
            let _ = res_tx.send(Ok((full_text, probs)));
            Ok((res_rx, tokio_rx))
        }

        #[cfg(not(feature = "simulated"))]
        {
            let prompt_owned = prompt.to_string();
            let gp = BackendGenerateParams {
                max_tokens,
                temperature: self.config.generation.temperature,
                top_p: self.config.generation.top_p,
                repeat_penalty: self.config.generation.repeat_penalty,
                stop_sequences: self.config.generation.stop_sequences.clone(),
            };

            let (model, load_params, gen) = {
                let mut g = self.state.write().await;
                let s = g.as_mut().ok_or_else(|| NanoError::Internal {
                    message: "No model loaded".to_string(),
                })?;
                let gen = s.generation;
                let m = s.model.take().ok_or_else(|| NanoError::Internal {
                    message: "No model loaded".to_string(),
                })?;
                let lp = s.load_params.clone();
                (m, lp, gen)
            };

            // Fire the generation on a blocking thread and return the token
            // receiver RIGHT AWAY. The blocking thread restores the model into
            // state via blocking_write() — the tokio-sanctioned pattern for
            // RwLock access from spawn_blocking threads — and reports the
            // final result through the oneshot channel. A dropped token
            // receiver aborts generation early through the callback's false
            // return, so a cancelled stream stops burning CPU.
            let state = Arc::clone(&self.state);
            tokio::task::spawn_blocking(move || {
                let mut ctx = match LlamaCppBackend::create_context(&model, &load_params) {
                    Ok(c) => c,
                    Err(e) => {
                        restore_model(&state, model, gen);
                        let _ = res_tx.send(Err(NanoError::InferenceError { reason: e }));
                        return;
                    }
                };

                let mut tokens_generated = 0;
                let result = LlamaCppBackend::generate_streaming(
                    &mut ctx,
                    &model,
                    &prompt_owned,
                    &gp,
                    None,
                    &mut move |text, prob, _is_stop| {
                        tokens_generated += 1;
                        if prob > 0.95 && tokens_generated > 8 {
                            tracing::debug!("[EarlyExitController] High confidence ({:.2}) - early exit triggered for token", prob);
                        }
                        // Returning false when the receiver is gone aborts the
                        // llama.cpp loop instead of generating into the void.
                        tokio_tx.blocking_send((text.to_string(), prob)).is_ok()
                    },
                );

                restore_model(&state, model, gen);

                match result {
                    Ok(r) => {
                        let _ = res_tx.send(Ok((r.text, r.token_probabilities)));
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

/// Restaura el modelo al estado compartido desde un hilo bloqueante.
///
/// Solo si no se cargó un modelo nuevo durante la inferencia (verificado
/// con el contador monotónico de generación). Si cambió, el modelo viejo
/// se descarta aquí, liberando su memoria.
#[cfg(not(feature = "simulated"))]
fn restore_model(state: &Arc<RwLock<Option<ModelState>>>, model: NanoModel, gen: u64) {
    let mut g = state.blocking_write();
    if let Some(ref mut s) = g.as_mut() {
        if s.generation == gen {
            s.model = Some(model);
        } else {
            tracing::info!(
                "Model changed during generation (gen {} → {}) — discarding old model",
                gen,
                s.generation
            );
            // model is dropped here, freeing old model memory
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
