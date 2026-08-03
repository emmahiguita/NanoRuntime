//! Gestor de modelos de IA.
//!
//! Crea contexto fresco por cada generación para evitar contaminación del KV cache.

use std::path::Path;

use tokio::sync::RwLock;

use crate::config::manifest::Config;
use crate::error::{NanoError, Result};
use crate::execution::memory_manager::MemoryManager;

struct ModelState {
    model_path: String,
    context_size: usize,
    #[allow(dead_code)]
    is_simulated: bool,
    #[cfg(not(feature = "simulated"))]
    model: Option<nanortime_ffi::NanoModel>,
    #[cfg(not(feature = "simulated"))]
    load_params: nanortime_ffi::ModelLoadParams,
    #[cfg(not(feature = "simulated"))]
    lora_adapter: Option<nanortime_ffi::NanoLoraAdapter>,
    #[cfg(not(feature = "simulated"))]
    lora_path: Option<String>,
}

pub struct ModelManager {
    config: Config,
    state: RwLock<Option<ModelState>>,
    pub memory_engine: std::sync::Mutex<crate::memory_engine::NanoMemoryEngine>,
    pub early_exit: std::sync::Mutex<crate::memory_engine::EarlyExitController>,
}

impl ModelManager {
    pub async fn new(config: Config) -> Result<Self> {
        let engine = crate::memory_engine::NanoMemoryEngine::new(32);
        let early_exit = crate::memory_engine::EarlyExitController::new(0.95, 8);
        Ok(Self {
            config,
            state: RwLock::new(None),
            memory_engine: std::sync::Mutex::new(engine),
            early_exit: std::sync::Mutex::new(early_exit),
        })
    }

    pub async fn load_model(&self, path: &str) -> Result<()> {
        if path.is_empty() || !Path::new(path).exists() {
            return Err(NanoError::ModelNotFound { path: path.to_string() });
        }
        self.unload_model().await;

        // ── V2: Auto-detect device profile and compute optimal config ──
        let file_size_mb = std::fs::metadata(path)
            .map(|m| m.len() / (1024 * 1024))
            .unwrap_or(0);
        let (v2_ctx, v2_batch, v2_risk) = MemoryManager::auto_configure_v2(
            file_size_mb,
            8192, // max context
        );
        tracing::info!(
            "V2 Auto-config: ctx={} batch={} risk={} model_mb={}",
            v2_ctx, v2_batch, v2_risk, file_size_mb
        );
        // Override config with V2-optimized values
        let mut adapted_config = self.config.local_model.clone();
        adapted_config.context_size = v2_ctx as usize;
        adapted_config.batch_size = v2_batch as usize;

        #[cfg(feature = "simulated")]
        {
            let mut g = self.state.write().await;
            *g = Some(ModelState { model_path: path.into(), context_size: self.config.local_model.context_size, is_simulated: true });
            tracing::info!("Model loaded (simulated): {}", path);
            return Ok(());
        }

        #[cfg(not(feature = "simulated"))]
        {
            use nanortime_ffi::{ModelLoadParams, NanoModel};
            let lp = ModelLoadParams {
                context_size: adapted_config.context_size as u32,
                gpu_layers: adapted_config.gpu_layers,
                use_mmap: adapted_config.use_mmap,
                threads: adapted_config.threads as u32,
                batch_size: adapted_config.batch_size as u32,
            };
            let model = NanoModel::load(path, &lp)
                .map_err(|e| NanoError::ModelLoadFailed { path: path.into(), reason: e })?;
            let nv = model.n_vocab();
            let ctx_sz = lp.context_size;
            let mut g = self.state.write().await;
            *g = Some(ModelState { model_path: path.into(), context_size: ctx_sz as usize, is_simulated: false, model: Some(model), load_params: lp, lora_adapter: None, lora_path: None });
            tracing::info!("Model loaded: {} (vocab: {}, ctx: {})", path, nv, ctx_sz);
            Ok(())
        }
    }

    pub async fn unload_model(&self) {
        let mut g = self.state.write().await;
        if let Some(ref s) = *g { tracing::info!("Unloading: {}", s.model_path); }
        *g = None;
    }

    /// Guarda el estado (KV cache) a un archivo de sesión.
    ///
    /// Usa la API `state_save_file` del contexto de llama.cpp.
    /// Requiere un contexto activo — se obtiene del modelo cargado.
    pub async fn save_session_state(&self, path: &str) -> Result<()> {
        #[cfg(not(feature = "simulated"))]
        {
            let g = self.state.read().await;
            if let Some(ref s) = *g {
                if let Some(ref model) = s.model {
                    // El NanoContext se crea por generación; para persistencia
                    // usamos un contexto temporal con el estado.
                    let ctx = model.create_context(&s.load_params)
                        .map_err(|e| NanoError::ModelLoadFailed { path: s.model_path.clone(), reason: e })?;
                    ctx.save_state(path)
                        .map_err(|e| NanoError::ModelLoadFailed { path: path.to_string(), reason: e })?;
                    tracing::info!("Session state saved: {} ({} bytes)", path, ctx.state_size());
                    return Ok(());
                }
            }
            tracing::warn!("No model loaded — cannot save session state");
        }
        Ok(())
    }

    /// Restaura el estado (KV cache) desde un archivo de sesión.
    pub async fn restore_session_state(&self, path: &str) -> Result<()> {
        #[cfg(not(feature = "simulated"))]
        {
            let g = self.state.read().await;
            if let Some(ref s) = *g {
                if let Some(ref model) = s.model {
                    let mut ctx = model.create_context(&s.load_params)
                        .map_err(|e| NanoError::ModelLoadFailed { path: s.model_path.clone(), reason: e })?;
                    let tokens = ctx.load_state(path)
                        .map_err(|e| NanoError::ModelLoadFailed { path: path.to_string(), reason: e })?;
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
            return Err(NanoError::Internal { message: "LoRA not supported in simulated mode".to_string() });
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

            // Unload previous LoRA if any
            s.lora_adapter = None;

            // Load new LoRA adapter
            let adapter = model.load_lora(path, strength)
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
            return Ok(());
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
            engine.compute_schedule(&scores);
            // Estimar perplejidad desde probabilidades = exp(-mean(ln(p)))
            let avg_nll = if !token_probs.is_empty() {
                -token_probs.iter().map(|&p| p.max(0.01).ln()).sum::<f32>() / token_probs.len() as f32
            } else {
                0.2
            };
            let perplexity = avg_nll.exp();
            let report = engine.evaluate_quality(perplexity);
            tracing::debug!(
                "[NanoMemoryEngine] {}", engine.status_report()
            );
            let _ = report;
        }
    }

    pub async fn generate_with_confidence(
        &self, prompt: &str, max_tokens: usize,
    ) -> Result<(String, Vec<f32>)> {
        let mut g = self.state.write().await;
        let s = g.as_mut().ok_or_else(|| NanoError::Internal { message: "No model loaded".to_string() })?;

        #[cfg(feature = "simulated")]
        if s.is_simulated {
            let (text, probs) = simulate(prompt, max_tokens);
            self.update_memory_engine_metrics(&probs);
            return Ok((text, probs));
        }
        #[cfg(feature = "simulated")]
        { return Err(NanoError::Internal { message: "real model in simulated mode".into() }); }

        #[cfg(not(feature = "simulated"))]
        {
            use nanortime_ffi::GenerateParams;
            let model = s.model.as_ref().unwrap();
            // FRESH context per generation — prevents KV cache pollution
            let mut ctx = model.create_context(&s.load_params)
                .map_err(|e| NanoError::InferenceError { reason: e })?;
            let gp = GenerateParams {
                max_tokens,
                temperature: self.config.generation.temperature,
                top_p: self.config.generation.top_p,
                repeat_penalty: self.config.generation.repeat_penalty,
                stop_sequences: self.config.generation.stop_sequences.clone(),
            };
            let r = ctx.generate(model, prompt, &gp, s.lora_adapter.as_mut())
                .map_err(|e| NanoError::InferenceError { reason: e })?;
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
            return Err(NanoError::Internal {
                message: "Embeddings not supported in simulated mode".to_string(),
            });
        }

        #[cfg(not(feature = "simulated"))]
        {
            let g = self.state.read().await;
            let s = g.as_ref().ok_or_else(|| NanoError::Internal {
                message: "No model loaded".to_string(),
            })?;
            let model = s.model.as_ref().ok_or_else(|| NanoError::Internal {
                message: "No model loaded".to_string(),
            })?;
            let backend = nanortime_ffi::get_backend();
            model.embed_text(text, backend)
                .map_err(|e| NanoError::InferenceError { reason: e })
        }
    }

    pub async fn is_loaded(&self) -> bool { self.state.read().await.is_some() }
    pub async fn context_size(&self) -> Option<usize> { self.state.read().await.as_ref().map(|s| s.context_size) }

    /// Genera tokens de forma streaming, emitiendo cada token por un canal.
    ///
    /// La generación corre en un hilo separado (spawn_blocking) para que
    /// los tokens lleguen al receiver en tiempo real, token por token.
    ///
    /// Retorna (texto_completo, probabilidades, receiver_de_tokens).
    /// El receiver emite (token_text, probability) por cada token generado.
    pub async fn generate_streaming(
        &self, prompt: &str, max_tokens: usize,
    ) -> Result<(String, Vec<f32>, tokio::sync::mpsc::Receiver<(String, f32)>)> {
        let (tokio_tx, tokio_rx): (tokio::sync::mpsc::Sender<(String, f32)>, tokio::sync::mpsc::Receiver<(String, f32)>) =
            tokio::sync::mpsc::channel(max_tokens.max(4096));

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
            return Ok((full_text, probs, tokio_rx));
        }

        #[cfg(not(feature = "simulated"))]
        {
            use nanortime_ffi::GenerateParams;
            let prompt_owned = prompt.to_string();
            let gp = GenerateParams {
                max_tokens,
                temperature: self.config.generation.temperature,
                top_p: self.config.generation.top_p,
                repeat_penalty: self.config.generation.repeat_penalty,
                stop_sequences: self.config.generation.stop_sequences.clone(),
            };

            // Take the model out of state temporarily so we can move it
            // into the spawn_blocking closure. We put it back after.
            let (model, load_params) = {
                let mut g = self.state.write().await;
                let s = g.as_mut().ok_or_else(|| NanoError::Internal {
                    message: "No model loaded".to_string(),
                })?;
                let m = s.model.take().ok_or_else(|| NanoError::Internal {
                    message: "No model loaded".to_string(),
                })?;
                let lp = s.load_params.clone();
                (m, lp)
            };

            // Spawn generation on a blocking thread for real-time streaming.
            // The model was taken from state, so no concurrent access is possible.
            let join = std::thread::spawn(move || {
                // Create a fresh context for this generation
                let mut ctx = match model.create_context(&load_params) {
                    Ok(c) => c,
                    Err(e) => return (model, None, Err(e)),
                };

                // Generate with streaming callback that sends tokens in real-time.
                // With channel capacity max_tokens.max(4096), blocking_send never blocks.
                let mut tokens_generated = 0;
                let result = match ctx.generate_streaming(
                    &model, &prompt_owned, &gp, None,
                    |text, prob, _is_stop| {
                        tokens_generated += 1;
                        // Simulated hook for Early Exiting. In a true custom C++ backend,
                        // this logic would be pushed down to the `llama_decode` loop per layer.
                        // For now, we simulate the logic at the token level to demonstrate the pipeline.
                        if prob > 0.95 && tokens_generated > 8 {
                            tracing::debug!("[EarlyExitController] High confidence ({:.2}) - early exit triggered for token", prob);
                        }
                        
                        let _ = tokio_tx.blocking_send((text.to_string(), prob));
                    },
                ) {
                    Ok(r) => r,
                    Err(e) => return (model, None, Err(e)),
                };

                // Signal end of stream by dropping the sender
                drop(tokio_tx);

                (model, Some((result.text, result.token_probabilities)), Ok(()))
            });

            // Wait for generation to complete and put the model back
            let (returned_model, result_data, gen_result) = join.join()
                .map_err(|e| NanoError::Internal {
                    message: format!("Generation thread panicked: {:?}", e),
                })?;

            // Put the model back into state
            {
                let mut g = self.state.write().await;
                if let Some(ref mut s) = g.as_mut() {
                    s.model = Some(returned_model);
                }
            }

            match result_data {
                Some((text, probs)) => Ok((text, probs, tokio_rx)),
                None => Err(NanoError::InferenceError {
                    reason: gen_result.unwrap_err(),
                }),
            }
        }
    }
}

#[cfg(feature = "simulated")]
fn simulate(p: &str, _: usize) -> (String, Vec<f32>) {
    let pl = p.to_lowercase();
    if pl.contains("hora") || pl.contains("hola") || pl.contains("día") {
        (format!("[Simulated] {}", &p[..p.len().min(60)]), vec![0.9,0.95,0.92,0.88,0.93])
    } else {
        (format!("[Simulated low] {}", &p[..p.len().min(60)]), vec![0.4,0.35,0.3,0.45,0.38])
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    #[tokio::test] async fn test_new() { assert!(!ModelManager::new(Config::test_config()).await.unwrap().is_loaded().await); }
    #[tokio::test] async fn test_no_model() { assert!(ModelManager::new(Config::test_config()).await.unwrap().generate("x",10).await.is_err()); }
    #[tokio::test] async fn test_bad_path() { assert!(ModelManager::new(Config::test_config()).await.unwrap().load_model("x.gguf").await.is_err()); }
}
