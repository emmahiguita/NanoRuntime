//! NanoAI FFI Bridge — Real llama.cpp inference via llama-cpp-2.
//!
//! Wraps the `llama-cpp-2` crate to provide a clean, safe API
//! for loading GGUF models and generating text with confidence scores.

use std::num::NonZeroU32;
use std::path::Path;
use std::sync::OnceLock;

use llama_cpp_2::context::params::LlamaContextParams;
use llama_cpp_2::llama_backend::LlamaBackend;
use llama_cpp_2::llama_batch::LlamaBatch;
use llama_cpp_2::model::params::LlamaModelParams;
use llama_cpp_2::model::{AddBos, LlamaLoraAdapter, LlamaModel};
use llama_cpp_2::token::LlamaToken;
use rand::Rng;

// ── Llama.cpp log suppression ──────────────────────────────────
// llama_log_set is not exposed in llama-cpp-sys-2's auto-generated
// bindings, so we declare it manually here.
extern "C" {
    fn llama_log_set(
        log_callback: Option<
            unsafe extern "C" fn(
                level: i32,
                text: *const std::ffi::c_char,
                user_data: *mut std::ffi::c_void,
            ),
        >,
        user_data: *mut std::ffi::c_void,
    );
}

/// Forward llama.cpp logs to tracing with level filtering.
///
/// llama.cpp log levels:
///   0 = LLAMA_LOG_LEVEL_ERROR
///   1 = LLAMA_LOG_LEVEL_WARN
///   2 = LLAMA_LOG_LEVEL_INFO
///   3+ = LLAMA_LOG_LEVEL_DEBUG / default
///
/// In debug builds, all levels are forwarded. In release builds, only
/// ERROR and WARN are forwarded — INFO/DEBUG noise (load:, repack:,
/// sched_reserve:, etc.) is suppressed so it never reaches stderr.
unsafe extern "C" fn llama_log_callback(
    level: i32,
    text: *const std::ffi::c_char,
    _user_data: *mut std::ffi::c_void,
) {
    // In release, suppress INFO (2) and DEBUG (3+)
    if !cfg!(debug_assertions) && level > 1 {
        return;
    }
    if text.is_null() {
        return;
    }
    let msg = unsafe { std::ffi::CStr::from_ptr(text) };
    let msg_str = msg.to_string_lossy();
    match level {
        0 => tracing::error!("[llama.cpp] {}", msg_str.trim_end()),
        1 => tracing::warn!("[llama.cpp] {}", msg_str.trim_end()),
        2 => tracing::info!("[llama.cpp] {}", msg_str.trim_end()),
        _ => tracing::debug!("[llama.cpp] {}", msg_str.trim_end()),
    }
}

static BACKEND: OnceLock<LlamaBackend> = OnceLock::new();

pub fn init_backend() -> Result<(), String> {
    BACKEND.get_or_init(|| {
        // Install llama.cpp log callback BEFORE initializing backend.
        // Release: only errors + warnings. Debug: all levels.
        unsafe {
            llama_log_set(Some(llama_log_callback), std::ptr::null_mut());
        }
        LlamaBackend::init().expect("Failed to init llama.cpp backend")
    });
    Ok(())
}

/// Returns a reference to the initialized backend.
/// Must call init_backend() first.
pub fn get_backend() -> &'static LlamaBackend {
    BACKEND
        .get()
        .expect("Backend not initialized. Call init_backend() first.")
}

pub struct NanoModel {
    // Own the model allocation so nano_model_free releases the real llama.cpp
    // model, not only the FFI wrapper. Contexts created from this model must be
    // freed before the model handle is freed; the C/JNI API documents that order.
    inner: Box<LlamaModel>,
    #[allow(dead_code)]
    path: String,
}

// SAFETY: NanoModel can be sent between threads because:
//   - The boxed LlamaModel has stable heap address while NanoModel is alive.
//   - llama.cpp does not use thread-local state for model data.
//   - ModelManager wraps access in RwLock, guaranteeing at most one writer
//     or multiple readers at any time.
//
// Sync is intentionally NOT implemented. llama.cpp models are NOT safe for
// concurrent reads from multiple threads (the C++ backend uses internal
// mutable state for weight quantization caches). ModelManager enforces
// single-threaded access via RwLock.
unsafe impl Send for NanoModel {}

pub struct NanoContext {
    inner: llama_cpp_2::context::LlamaContext<'static>,
    context_size: u32,
    batch_size: u32,
    cached_tokens: Vec<LlamaToken>,
}

// SAFETY: NanoContext is moved only as an exclusive value by ModelManager.
// Generation takes `&mut NanoContext`, ModelManager removes it from shared
// state while a blocking thread owns it, and restores it after inference. It is
// never accessed concurrently.
unsafe impl Send for NanoContext {}
unsafe impl Sync for NanoContext {}

#[derive(Debug, Clone)]
pub struct ModelLoadParams {
    pub context_size: u32,
    pub gpu_layers: i32,
    pub use_mmap: bool,
    pub threads: u32,
    pub batch_size: u32,
}

impl Default for ModelLoadParams {
    fn default() -> Self {
        Self {
            context_size: 8192,
            gpu_layers: 0,
            use_mmap: true,
            threads: 4,
            batch_size: 512,
        }
    }
}

#[derive(Debug, Clone)]
pub struct GenerateParams {
    pub max_tokens: usize,
    pub temperature: f32,
    pub top_p: f32,
    pub repeat_penalty: f32,
    pub stop_sequences: Vec<String>,
}

impl Default for GenerateParams {
    fn default() -> Self {
        Self {
            max_tokens: 2048,
            temperature: 0.7,
            top_p: 0.9,
            repeat_penalty: 1.1,
            stop_sequences: vec!["</s>".into(), "<|endoftext|>".into(), "<|im_end|>".into()],
        }
    }
}

pub struct GenerateResult {
    pub text: String,
    pub token_probabilities: Vec<f32>,
    pub tokens_generated: usize,
    pub tokens_per_second: f64,
}

impl NanoModel {
    pub fn load(path: &str, params: &ModelLoadParams) -> Result<Self, String> {
        init_backend()?;
        let backend = BACKEND.get().unwrap();
        let model_path = Path::new(path);
        if !model_path.exists() {
            return Err(format!("Model file not found: {}", path));
        }
        // Aplicar el config real: use_mmap decide si los pesos se mmap-ean
        // (crítico en Android: sin mmap un GGUF de 27B no cabe en RAM) y
        // gpu_layers (0 = solo CPU). Antes se ignoraban y se usaba el default.
        let model_params = LlamaModelParams::default()
            .with_use_mmap(params.use_mmap)
            .with_n_gpu_layers(params.gpu_layers.max(0) as u32);
        let inner = LlamaModel::load_from_file(backend, model_path, &model_params)
            .map_err(|e| format!("Failed to load model '{}': {}", path, e))?;
        let vocab = inner.n_vocab();
        tracing::info!(
            "Loaded model: {} ({} vocab, mmap={}, gpu_layers={})",
            path,
            vocab,
            params.use_mmap,
            params.gpu_layers
        );
        Ok(Self {
            inner: Box::new(inner),
            path: path.to_string(),
        })
    }

    /// Base address + size (bytes) of the primary mmap of the model file.
    /// `(null, 0)` if the model was not mmap'd. NanoRuntime's OS-like layer
    /// streaming uses this with per-tensor GGUF offsets to madvise layers.
    pub fn mmap_addr(&self) -> (*mut std::ffi::c_void, usize) {
        self.inner.mmap_addr()
    }

    pub fn create_context(&self, params: &ModelLoadParams) -> Result<NanoContext, String> {
        init_backend()?;
        let backend = BACKEND.get().unwrap();
        // Thread tuning: on big.LITTLE (Exynos, Snapdragon), using all cores
        // causes cache thrashing and LOWER throughput. Using 4 threads keeps
        // inference on big cores only, yielding 1.3-1.8× speedup over default.
        let thread_count = params.threads as i32;
        let ctx_params = LlamaContextParams::default()
            .with_n_ctx(NonZeroU32::new(params.context_size))
            .with_n_batch(params.batch_size)
            .with_n_threads(thread_count)
            .with_n_threads_batch(thread_count);
        let inner = self
            .inner
            .new_context(backend, ctx_params)
            .map_err(|e| format!("Failed to create context: {}", e))?;
        // SAFETY: Extending the context lifetime to 'static is valid only while
        // callers uphold the FFI ownership contract:
        //   1. NanoContext handles created from a NanoModel must be freed before
        //      nano_model_free is called for that model.
        //   2. The C++ llama.cpp backend stores model weights in a flat memory
        //      buffer. LlamaContext holds a raw pointer into this buffer, not
        //      a Rust reference. The buffer remains valid while NanoModel exists.
        //   3. transmute is used instead of a hypothetical into_static() because
        //      the llama-cpp-2 crate does not expose a lifetime-extending API.
        //      The transmute ONLY changes the lifetime parameter; the concrete
        //      type LlamaContext<'_> → LlamaContext<'static> is layout-identical.
        //   4. ModelManager guarantees NanoModel outlives all contexts (drop order).
        // Panic-safety: if this thread panics, the process aborts (FFI boundary),
        // so poisoned state is not observable by other threads.
        let inner: llama_cpp_2::context::LlamaContext<'static> =
            unsafe { std::mem::transmute(inner) };
        tracing::info!(
            "Created context: {} tokens, {} batch",
            params.context_size,
            params.batch_size
        );
        Ok(NanoContext {
            inner,
            context_size: params.context_size,
            batch_size: params.batch_size.max(1),
            cached_tokens: Vec::new(),
        })
    }

    pub fn tokenize(&self, text: &str, add_bos: bool) -> Result<Vec<LlamaToken>, String> {
        let bos = if add_bos {
            AddBos::Always
        } else {
            AddBos::Never
        };
        self.inner
            .str_to_token(text, bos)
            .map_err(|e| format!("Tokenization failed: {}", e))
    }

    pub fn token_to_text(&self, token: LlamaToken) -> Result<String, String> {
        let mut decoder = encoding_rs::UTF_8.new_decoder();
        match self.inner.token_to_piece(token, &mut decoder, true, None) {
            Ok(text) => Ok(text),
            Err(_) => Ok(String::new()), // Control/special tokens → empty string
        }
    }

    pub fn token_eos(&self) -> LlamaToken {
        self.inner.token_eos()
    }

    pub fn n_vocab(&self) -> i32 {
        self.inner.n_vocab()
    }

    pub fn n_layer(&self) -> u32 {
        self.inner.n_layer()
    }

    /// Lee el chat template desde la metadata del GGUF.
    ///
    /// Llaves estándar: `tokenizer.chat_template` (la más común) y
    /// `tokenizer.ggml.chat_template` (variante antigua). Devuelve None si el
    /// modelo no trae template (modelos base) o si la metadata no está
    /// disponible. Permite detectar instruct-ness sin depender del nombre
    /// del archivo.
    pub fn chat_template(&self) -> Option<String> {
        self.inner
            .meta_val_str("tokenizer.chat_template")
            .or_else(|_| self.inner.meta_val_str("tokenizer.ggml.chat_template"))
            .ok()
    }

    pub fn estimate_tokens(text: &str) -> usize {
        text.len().div_ceil(4)
    }

    /// Genera un embedding para un texto usando el modelo.
    ///
    /// Crea un contexto temporal con `embeddings=true`, tokeniza el texto,
    /// lo procesa, y extrae el vector de embedding de la última posición.
    /// Retorna el vector de embedding (dimensión = n_embd del modelo).
    pub fn embed_text(&self, text: &str, backend: &LlamaBackend) -> Result<Vec<f32>, String> {
        // Context params with embeddings enabled and minimal settings
        let ctx_params = LlamaContextParams::default()
            .with_embeddings(true)
            .with_n_ctx(NonZeroU32::new(512))
            .with_n_batch(512);

        let ctx = self
            .inner
            .new_context(backend, ctx_params)
            .map_err(|e| format!("Failed to create embedding context: {}", e))?;

        // SAFETY: Same lifetime invariant as create_context (see above).
        // The embedding context is local to this call and drops before NanoModel.
        // transmute only extends the lifetime parameter — LlamaContext<'static>
        // is layout-identical to LlamaContext<'_>.
        let mut ctx: llama_cpp_2::context::LlamaContext<'static> =
            unsafe { std::mem::transmute(ctx) };

        // Tokenize
        let tokens = self
            .inner
            .str_to_token(text, AddBos::Always)
            .map_err(|e| format!("Tokenization failed: {}", e))?;

        if tokens.is_empty() {
            return Err("Empty tokenization result".to_string());
        }

        // Process all tokens (no generation needed)
        let mut n_past = 0i32;
        for chunk in tokens.chunks(1024) {
            let mut batch = LlamaBatch::new(chunk.len(), 1);
            for (i, &token) in chunk.iter().enumerate() {
                batch
                    .add(token, n_past + i as i32, &[0], false)
                    .map_err(|e| format!("Batch add: {}", e))?;
            }
            ctx.decode(&mut batch)
                .map_err(|e| format!("Decode: {}", e))?;
            n_past += chunk.len() as i32;
        }

        // Get embedding for last sequence (position 0, seq 0)
        let emb = ctx
            .embeddings_ith(0)
            .map_err(|e| format!("Failed to get embeddings: {:?}", e))?;

        Ok(emb.to_vec())
    }

    /// Carga un adaptador LoRA desde un archivo.
    ///
    /// El archivo debe ser un checkpoint LoRA en formato GGUF.
    /// Retorna un `NanoLoraAdapter` que se puede aplicar a un contexto
    /// durante la generación.
    pub fn load_lora(&self, path: &str, _strength: f32) -> Result<NanoLoraAdapter, String> {
        let lora_path = std::path::Path::new(path);
        if !lora_path.exists() {
            return Err(format!("LoRA file not found: {}", path));
        }
        let adapter = self
            .inner
            .lora_adapter_init(lora_path)
            .map_err(|e| format!("Failed to load LoRA adapter '{}': {:?}", path, e))?;
        tracing::info!("Loaded LoRA adapter: {}", path);
        Ok(NanoLoraAdapter(adapter))
    }
}

/// Adaptador LoRA para ajuste fino en caliente.
///
/// Se carga desde un archivo GGUF de LoRA y se aplica a un contexto
/// de inferencia para modificar el comportamiento del modelo base.
pub struct NanoLoraAdapter(LlamaLoraAdapter);

// SAFETY: NanoLoraAdapter wraps a llama.cpp LoRA adapter handle.
// The underlying C data is in process-wide memory and llama.cpp does
// not use thread-local state for adapter weights. The adapter is owned
// exclusively — only one Rust wrapper exists per C handle.
unsafe impl Send for NanoLoraAdapter {}

// SAFETY: LoRA adapter weights are read-only after loading. All mutable
// operations (apply/remove) go through ModelManager's RwLock, which
// serializes access. The underlying llama.cpp C data is not mutated by
// concurrent reads.
unsafe impl Sync for NanoLoraAdapter {}

impl NanoContext {
    pub fn generate(
        &mut self,
        model: &NanoModel,
        prompt: &str,
        params: &GenerateParams,
        mut lora: Option<&mut NanoLoraAdapter>,
    ) -> Result<GenerateResult, String> {
        let start = std::time::Instant::now();

        // Apply LoRA adapter if provided (scope ensures borrow released after)
        let had_lora = lora.is_some();
        if had_lora {
            // We know it's Some from the check above; unwrap is safe.
            let adapter: &mut NanoLoraAdapter = lora.as_mut().unwrap();
            self.inner
                .lora_adapter_set(&mut adapter.0, 1.0)
                .map_err(|e| format!("Failed to apply LoRA: {:?}", e))?;
            tracing::debug!("LoRA adapter applied");
        }

        // ── Tokenization and generation ──────────────────────

        let tokens = model.tokenize(prompt, true)?;
        let n_prompt = tokens.len();
        if tokens.is_empty() {
            return Err("Empty prompt".to_string());
        }
        if n_prompt as u32 >= self.context_size {
            return Err(format!(
                "Prompt too long: {} tokens exceeds context size {}",
                n_prompt, self.context_size
            ));
        }

        let mut n_past: i32 = 0;
        let prefill_batch = self.batch_size as usize;

        // Process prompt: all tokens except last (no logits), then last with logits.
        if tokens.len() == 1 {
            let mut batch = LlamaBatch::new(1, 1);
            batch
                .add(tokens[0], 0, &[0], true)
                .map_err(|e| format!("Batch add: {}", e))?;
            self.inner
                .decode(&mut batch)
                .map_err(|e| format!("Decode: {}", e))?;
            n_past = 1;
        } else {
            let (prompt_tokens, last_tok) = tokens.split_at(tokens.len() - 1);

            for chunk in prompt_tokens.chunks(prefill_batch) {
                let mut batch = LlamaBatch::new(chunk.len(), 1);
                for (i, &token) in chunk.iter().enumerate() {
                    batch
                        .add(token, n_past + i as i32, &[0], false)
                        .map_err(|e| format!("Batch add: {}", e))?;
                }
                self.inner
                    .decode(&mut batch)
                    .map_err(|e| format!("Decode: {}", e))?;
                n_past += chunk.len() as i32;
            }

            let mut batch = LlamaBatch::new(1, 1);
            batch
                .add(last_tok[0], n_past, &[0], true)
                .map_err(|e| format!("Batch add: {}", e))?;
            self.inner
                .decode(&mut batch)
                .map_err(|e| format!("Decode: {}", e))?;
            n_past += 1;
        }

        // Manual temperature sampling using raw logits.
        // Avoids LlamaSampler::temp() crash on Windows (llama-cpp-sys-2 v0.1.153 bug).
        let eos = model.token_eos();
        let mut output = String::new();
        let mut token_probs = Vec::with_capacity(params.max_tokens);
        let mut rng = rand::thread_rng();
        // Historial de tokens emitidos para repeat_penalty (el prompt NO se
        // penaliza — solo la salida generada, igual que llama.cpp con
        // penalty_last_n cubriendo la ventana de generación).
        let mut generated: Vec<LlamaToken> = Vec::with_capacity(params.max_tokens);

        // Sample first generated token from logits at batch position 0.
        let logits = self.inner.get_logits_ith(0);
        let first_token = sample_token(logits, params.temperature, params.top_p, &mut rng);
        let mut last_token = first_token;
        generated.push(first_token);

        // Always push first token probability — even EOS.
        // token_confidence() returns None on empty arrays, causing
        // confidence=0.000 in metrics. A single EOS token with prob 1.0
        // means the model was fully confident it had nothing to say.
        {
            let probs = apply_temperature_and_softmax(logits, params.temperature);
            let prob = probs.get(first_token.0 as usize).copied().unwrap_or(0.5);
            token_probs.push(prob);
        }

        if first_token != eos {
            let piece = model.token_to_text(first_token)?;
            let should_stop = params.stop_sequences.iter().any(|s| piece.contains(s));
            if !should_stop {
                output.push_str(&piece);
            }
        }

        // Generate remaining tokens one at a time: add → decode → sample
        for _ in 1..params.max_tokens {
            if last_token == eos {
                break;
            }
            if n_past as u32 >= self.context_size {
                tracing::warn!(
                    "[NanoContext] context limit reached ({} tokens) — truncating output",
                    self.context_size
                );
                break;
            }

            let mut batch = LlamaBatch::new(1, 1);
            batch
                .add(last_token, n_past, &[0], true)
                .map_err(|e| format!("Batch add: {}", e))?;
            self.inner
                .decode(&mut batch)
                .map_err(|e| format!("Decode: {}", e))?;
            n_past += 1;

            let logits = self.inner.get_logits_ith(0);
            let penalized = apply_repeat_penalty(logits, params.repeat_penalty, &generated);
            let effective: &[f32] = penalized.as_deref().unwrap_or(logits);
            let token = sample_token(effective, params.temperature, params.top_p, &mut rng);
            last_token = token;
            generated.push(token);
            // Push probability BEFORE checking EOS — ensures confidence
            // array is never empty even when model terminates immediately.
            {
                let probs = apply_temperature_and_softmax(effective, params.temperature);
                let prob = probs.get(token.0 as usize).copied().unwrap_or(0.5);
                token_probs.push(prob);
            }
            if token == eos {
                break;
            }

            let piece = model.token_to_text(token)?;
            // Only check the recent suffix against stop sequences.
            // Cloning the full output each token is O(n²) — with 2048 tokens
            // that is ~2M string clone operations. Instead, build a window
            // from the tail: longest stop sequence + current piece.
            // Must align to a valid UTF-8 character boundary to avoid panics
            // on multi-byte characters (ñ, ¿, emoji, etc.).
            // +4 slack para safe_utf8_boundary: retroceder hasta 3 bytes no
            // debe recortar un stop sequence que termine en el borde.
            let max_stop = params
                .stop_sequences
                .iter()
                .map(|s| s.len())
                .max()
                .unwrap_or(64);
            let candidate_start = output.len().saturating_sub(max_stop + piece.len() + 4);
            let win = safe_utf8_boundary(&output, candidate_start);
            let recent = format!("{}{}", &output[win..], piece);
            if params.stop_sequences.iter().any(|s| recent.contains(s)) {
                break;
            }

            output.push_str(&piece);
        }

        let elapsed = start.elapsed().as_secs_f64();
        let tokens_generated = n_past as usize - n_prompt;
        let tps = if elapsed > 0.0 {
            tokens_generated as f64 / elapsed
        } else {
            0.0
        };

        // Remove LoRA adapter if it was applied
        if had_lora {
            let adapter: &mut NanoLoraAdapter = lora.as_mut().unwrap();
            let _ = self.inner.lora_adapter_remove(&mut adapter.0);
            tracing::debug!("LoRA adapter removed");
        }

        Ok(GenerateResult {
            text: output,
            token_probabilities: token_probs,
            tokens_generated,
            tokens_per_second: tps,
        })
    }

    pub fn context_size(&self) -> u32 {
        self.context_size
    }

    pub fn clear_kv_cache(&mut self) {
        self.inner.clear_kv_cache();
        self.cached_tokens.clear();
    }

    // ── Session Persistence (KV cache state) ────────────────────
    // Guarda/restaura el estado completo (KV cache) para eliminar
    // la espera de prefill en la siguiente sesión. Byte-idéntico.

    /// Tamaño del estado del contexto (KV cache) en bytes.
    pub fn state_size(&self) -> usize {
        self.inner.get_state_size()
    }

    /// Guarda el estado (KV cache) a un archivo.
    ///
    /// Los tokens del contexto (`cached_tokens`) se guardan junto con el KV:
    /// llama.cpp los usa en la restauración para reubicar las posiciones de
    /// cada celda del cache. Guardar con lista vacía dejaba el KV inutilizable
    /// (las posiciones se perdían al recargar).
    ///
    /// Devuelve el número de bytes escritos.
    pub fn save_state(&self, path: &str) -> Result<usize, String> {
        self.inner
            .state_save_file(path, &self.cached_tokens)
            .map_err(|e| format!("Failed to save state: {:?}", e))?;
        Ok(self.inner.get_state_size())
    }

    /// Restaura el estado (KV cache) desde un archivo.
    ///
    /// Devuelve el número de tokens restaurados y actualiza `cached_tokens`
    /// para que el prefix reuse de la próxima generación sepa qué hay en el KV.
    pub fn load_state(&mut self, path: &str) -> Result<usize, String> {
        let tokens = self
            .inner
            .state_load_file(path, self.context_size as usize)
            .map_err(|e| format!("Failed to load state: {:?}", e))?;
        self.cached_tokens = tokens.clone();
        Ok(tokens.len())
    }

    /// Verifica si un archivo de estado existe y tiene tamaño válido.
    pub fn has_valid_state(&self, path: &str) -> bool {
        std::path::Path::new(path).exists()
            && std::fs::metadata(path)
                .map(|m| m.len() > 0)
                .unwrap_or(false)
    }

    /// Genera tokens de forma streaming, llamando al callback por cada token.
    ///
    /// El callback recibe (token_text, probability, is_stop) y retorna `false`
    /// para abortar la generación de inmediato (el resultado parcial se
    /// devuelve con el texto acumulado hasta ese punto).
    pub fn generate_streaming(
        &mut self,
        model: &NanoModel,
        prompt: &str,
        params: &GenerateParams,
        mut lora: Option<&mut NanoLoraAdapter>,
        mut on_token: impl FnMut(&str, f32, bool) -> bool,
    ) -> Result<GenerateResult, String> {
        let start = std::time::Instant::now();

        // Apply LoRA adapter if provided
        let had_lora = lora.is_some();
        if had_lora {
            let adapter: &mut NanoLoraAdapter = lora.as_mut().unwrap();
            self.inner
                .lora_adapter_set(&mut adapter.0, 1.0)
                .map_err(|e| format!("Failed to apply LoRA: {:?}", e))?;
        }

        // Tokenization and prompt processing (same as generate)
        let tokens = model.tokenize(prompt, true)?;
        let n_prompt = tokens.len();
        if tokens.is_empty() {
            return Err("Empty prompt".to_string());
        }
        if n_prompt as u32 >= self.context_size {
            return Err(format!(
                "Prompt too long: {} tokens exceeds context size {}",
                n_prompt, self.context_size
            ));
        }

        let prefill_batch = self.batch_size as usize;
        let mut common_prefix = self
            .cached_tokens
            .iter()
            .zip(tokens.iter())
            .take_while(|(cached, current)| cached == current)
            .count();

        // The final prompt token must be decoded with logits=true, so do not
        // reuse it blindly from cache. Re-decode that boundary token.
        common_prefix = common_prefix.min(tokens.len().saturating_sub(1));

        if common_prefix == 0 {
            self.inner.clear_kv_cache();
            self.cached_tokens.clear();
        } else if common_prefix < self.cached_tokens.len() {
            // Recortar la cola cacheada. Los modelos recurrentes/híbridos
            // (qwen35/SSM) NO soportan partial sequence removal: llama.cpp
            // devuelve false. En ese caso invalidamos el KV completo y
            // reconstruimos desde cero — más lento pero correcto, nunca
            // continuar con un KV inconsistente.
            match self
                .inner
                .kv_cache_seq_rm(0, Some(common_prefix as u32), None)
            {
                Ok(()) => {
                    self.cached_tokens.truncate(common_prefix);
                }
                Err(_) => {
                    tracing::warn!(
                        "KV partial trim no soportado (modelo recurrente) — invalidando KV completo y reconstruyendo"
                    );
                    self.inner.clear_kv_cache();
                    self.cached_tokens.clear();
                    common_prefix = 0;
                }
            }
        }

        let mut n_past: i32 = common_prefix as i32;
        let missing = &tokens[common_prefix..];

        if missing.is_empty() {
            // This should be rare because common_prefix is capped below the full
            // prompt, but keep behavior total for degenerate one-token prompts.
            let token = *tokens.last().unwrap();
            self.inner
                .kv_cache_seq_rm(0, Some(n_past.saturating_sub(1) as u32), None)
                .map_err(|e| format!("KV cache boundary trim failed: {}", e))?;
            n_past = n_past.saturating_sub(1);
            let mut batch = LlamaBatch::new(1, 1);
            batch
                .add(token, n_past, &[0], true)
                .map_err(|e| format!("Batch add: {}", e))?;
            self.inner
                .decode(&mut batch)
                .map_err(|e| format!("Decode: {}", e))?;
            n_past += 1;
            self.cached_tokens.push(token);
        } else if missing.len() == 1 {
            let mut batch = LlamaBatch::new(1, 1);
            batch
                .add(missing[0], n_past, &[0], true)
                .map_err(|e| format!("Batch add: {}", e))?;
            self.inner
                .decode(&mut batch)
                .map_err(|e| format!("Decode: {}", e))?;
            n_past += 1;
            self.cached_tokens.push(missing[0]);
        } else {
            let (prompt_tokens, last_tok) = missing.split_at(missing.len() - 1);
            for chunk in prompt_tokens.chunks(prefill_batch) {
                let mut batch = LlamaBatch::new(chunk.len(), 1);
                for (i, &token) in chunk.iter().enumerate() {
                    batch
                        .add(token, n_past + i as i32, &[0], false)
                        .map_err(|e| format!("Batch add: {}", e))?;
                }
                self.inner
                    .decode(&mut batch)
                    .map_err(|e| format!("Decode: {}", e))?;
                n_past += chunk.len() as i32;
                self.cached_tokens.extend_from_slice(chunk);
            }
            let mut batch = LlamaBatch::new(1, 1);
            batch
                .add(last_tok[0], n_past, &[0], true)
                .map_err(|e| format!("Batch add: {}", e))?;
            self.inner
                .decode(&mut batch)
                .map_err(|e| format!("Decode: {}", e))?;
            n_past += 1;
            self.cached_tokens.push(last_tok[0]);
        }

        tracing::info!(
            "[NanoKV] prompt_tokens={} reused={} decoded={}",
            n_prompt,
            common_prefix,
            n_prompt.saturating_sub(common_prefix)
        );

        let eos = model.token_eos();
        let mut output = String::new();
        let mut token_probs = Vec::with_capacity(params.max_tokens);
        let mut rng = rand::thread_rng();

        // Sample first token
        let logits = self.inner.get_logits_ith(0);
        let first_token = sample_token(logits, params.temperature, params.top_p, &mut rng);
        let mut last_token = first_token;

        // Always push first token probability — even EOS — so confidence
        // arrays are never empty (avoids confidence=0.000 in metrics).
        let first_prob = {
            let probs = apply_temperature_and_softmax(logits, params.temperature);
            probs.get(first_token.0 as usize).copied().unwrap_or(0.5)
        };
        token_probs.push(first_prob);

        let mut aborted = false;
        let mut generated_tokens = Vec::with_capacity(params.max_tokens);
        generated_tokens.push(first_token);

        if first_token != eos {
            let piece = model.token_to_text(first_token)?;
            let should_stop = params.stop_sequences.iter().any(|s| piece.contains(s));
            if !should_stop {
                output.push_str(&piece);
                // Callback returns false when the token receiver is gone:
                // abort instead of burning CPU with no listener.
                if !on_token(&piece, first_prob, false) {
                    aborted = true;
                }
            }
        }

        // Generate remaining tokens
        for _ in 1..params.max_tokens {
            if aborted || last_token == eos {
                break;
            }
            if n_past as u32 >= self.context_size {
                tracing::warn!(
                    "[NanoContext] context limit reached ({} tokens) — truncating streaming output",
                    self.context_size
                );
                break;
            }

            let mut batch = LlamaBatch::new(1, 1);
            batch
                .add(last_token, n_past, &[0], true)
                .map_err(|e| format!("Batch add: {}", e))?;
            self.inner
                .decode(&mut batch)
                .map_err(|e| format!("Decode: {}", e))?;
            n_past += 1;

            let logits = self.inner.get_logits_ith(0);
            let penalized =
                apply_repeat_penalty(logits, params.repeat_penalty, &generated_tokens);
            let effective: &[f32] = penalized.as_deref().unwrap_or(logits);
            let token = sample_token(effective, params.temperature, params.top_p, &mut rng);
            last_token = token;
            generated_tokens.push(token);
            // Push probability BEFORE EOS check — so confidence is available
            // even when model terminates immediately.
            let token_prob = {
                let probs = apply_temperature_and_softmax(effective, params.temperature);
                probs.get(token.0 as usize).copied().unwrap_or(0.5)
            };
            token_probs.push(token_prob);
            if token == eos {
                on_token("", 1.0, true);
                break;
            }

            let piece = model.token_to_text(token)?;
            // Only check the recent suffix against stop sequences.
            // Must align to a valid UTF-8 character boundary to avoid panics
            // on multi-byte characters (ñ, ¿, emoji, etc.).
            // +4 slack para safe_utf8_boundary (retrocede hasta 3 bytes).
            let max_stop = params
                .stop_sequences
                .iter()
                .map(|s| s.len())
                .max()
                .unwrap_or(64);
            let candidate_start = output.len().saturating_sub(max_stop + piece.len() + 4);
            let win = safe_utf8_boundary(&output, candidate_start);
            let recent = format!("{}{}", &output[win..], piece);
            if params.stop_sequences.iter().any(|s| recent.contains(s)) {
                break;
            }

            output.push_str(&piece);
            if !on_token(&piece, token_prob, false) {
                break;
            }
        }

        self.cached_tokens.extend(generated_tokens.iter().copied());

        let elapsed = start.elapsed().as_secs_f64();
        let tokens_generated = n_past as usize - n_prompt;
        let tps = if elapsed > 0.0 {
            tokens_generated as f64 / elapsed
        } else {
            0.0
        };

        // Remove LoRA adapter if it was applied
        if had_lora {
            let adapter: &mut NanoLoraAdapter = lora.as_mut().unwrap();
            let _ = self.inner.lora_adapter_remove(&mut adapter.0);
        }

        Ok(GenerateResult {
            text: output,
            token_probabilities: token_probs,
            tokens_generated,
            tokens_per_second: tps,
        })
    }
}

/// Finds the nearest valid UTF-8 character boundary at or before `index`.
///
/// String slicing (`&s[i..]`) panics if `i` falls in the middle of a multi-byte
/// character. This function walks backward from `index` to find a safe boundary.
/// On empty strings or when `index` is already valid, returns `index` unchanged.
fn safe_utf8_boundary(s: &str, index: usize) -> usize {
    if s.is_empty() || index == 0 {
        return 0;
    }
    let mut pos = index.min(s.len());
    // Walk backward until we hit a valid UTF-8 boundary
    while pos > 0 && !s.is_char_boundary(pos) {
        pos -= 1;
    }
    pos
}

/// Aplica repeat_penalty sobre los logits de tokens ya emitidos en esta
/// generación. Fórmula de llama.cpp: logit < 0 → logit * penalty;
/// logit >= 0 → logit / penalty (penalty > 1 baja la probabilidad de repetir).
///
/// Devuelve None cuando no hay penalización que aplicar (penalty ≈ 1.0 o
/// historial vacío): los callers usan el slice original sin clonar, así el
/// caso por defecto no paga el costo de copiar el vocabulario completo.
fn apply_repeat_penalty(
    logits: &[f32],
    repeat_penalty: f32,
    history: &[LlamaToken],
) -> Option<Vec<f32>> {
    if (repeat_penalty - 1.0).abs() <= f32::EPSILON || history.is_empty() {
        return None;
    }
    let mut penalized = logits.to_vec();
    for t in history {
        let idx = t.0 as usize;
        if idx >= penalized.len() {
            continue;
        }
        let v = penalized[idx];
        penalized[idx] = if v < 0.0 {
            v * repeat_penalty
        } else {
            v / repeat_penalty
        };
    }
    Some(penalized)
}

/// Sample un token de una distribución de logits usando temperatura y top-p.
///
/// Algoritmo:
/// 1. Si temp ≤ 0 → greedy (argmax)
/// 2. Si top_p < 1.0 → nucleus sampling sobre distribución con temperatura
/// 3. Sino → multinomial sampling completo
fn sample_token(logits: &[f32], temperature: f32, top_p: f32, rng: &mut impl Rng) -> LlamaToken {
    if temperature <= 0.0 {
        // Greedy: pick highest probability token
        let (idx, _) = logits
            .iter()
            .enumerate()
            .max_by(|(_, a), (_, b)| a.partial_cmp(b).unwrap_or(std::cmp::Ordering::Equal))
            .unwrap_or((0, &0.0));
        return LlamaToken::new(idx as i32);
    }

    // Apply temperature scaling and softmax
    let probs = apply_temperature_and_softmax(logits, temperature);

    // Top-p (nucleus) sampling
    if top_p < 1.0 {
        return nucleus_sample(&probs, top_p, rng);
    }

    // Full multinomial sampling
    multinomial_sample(&probs, rng)
}

/// Aplica temperatura y softmax a logits crudos.
/// Retorna probabilidades normalizadas (sum = 1.0).
fn apply_temperature_and_softmax(logits: &[f32], temperature: f32) -> Vec<f32> {
    if logits.is_empty() {
        return vec![];
    }

    let inv_temp = if temperature > 0.0 {
        1.0 / temperature
    } else {
        1.0
    };

    // Numerically stable softmax: subtract max before exp
    let max_logit = logits.iter().cloned().fold(f32::NEG_INFINITY, f32::max);

    let exps: Vec<f32> = logits
        .iter()
        .map(|&l| ((l - max_logit) * inv_temp).exp())
        .collect();

    let sum: f32 = exps.iter().sum();
    if sum <= 0.0 || !sum.is_finite() {
        // Fallback: uniform distribution
        let n = logits.len() as f32;
        return vec![1.0 / n; logits.len()];
    }

    exps.iter().map(|&e| e / sum).collect()
}

/// Nucleus (top-p) sampling: selecciona del subconjunto de tokens
/// cuya probabilidad acumulada alcanza top_p.
fn nucleus_sample(probs: &[f32], top_p: f32, rng: &mut impl Rng) -> LlamaToken {
    let mut indexed: Vec<(i32, f32)> = probs
        .iter()
        .enumerate()
        .map(|(i, &p)| (i as i32, p))
        .collect();

    // Sort by probability descending
    indexed.sort_by(|a, b| b.1.partial_cmp(&a.1).unwrap_or(std::cmp::Ordering::Equal));

    // Find the cutoff where cumulative probability >= top_p
    let mut cumulative = 0.0;
    let cutoff_idx = indexed
        .iter()
        .position(|(_, p)| {
            cumulative += *p;
            cumulative >= top_p
        })
        .unwrap_or(indexed.len() - 1);

    // Truncate to nucleus
    indexed.truncate(cutoff_idx + 1);
    let nucleus_sum: f32 = indexed.iter().map(|(_, p)| p).sum();

    // Sample from nucleus
    let r: f32 = rng.gen_range(0.0..nucleus_sum.max(f32::EPSILON));
    let mut cum = 0.0;
    for (token, p) in &indexed {
        cum += p;
        if r <= cum {
            return LlamaToken::new(*token);
        }
    }

    // Fallback: most probable token in nucleus
    LlamaToken::new(indexed[0].0)
}

/// Multinomial sampling: selecciona un token según su probabilidad.
fn multinomial_sample(probs: &[f32], rng: &mut impl Rng) -> LlamaToken {
    if probs.is_empty() {
        return LlamaToken::new(0);
    }

    let total: f32 = probs.iter().sum();
    let r: f32 = rng.gen_range(0.0..total.max(f32::EPSILON));

    let mut cum = 0.0;
    for (i, &p) in probs.iter().enumerate() {
        cum += p;
        if r <= cum {
            return LlamaToken::new(i as i32);
        }
    }

    // Fallback: last token
    LlamaToken::new((probs.len() - 1) as i32)
}

// ── C-FFI Exported Functions for Android / Native Integration ────────

use std::ffi::{CStr, CString};
use std::os::raw::c_char;

/// Initialise the llama.cpp backend. Must be called once before any model loading.
/// Returns 0 on success, -1 on failure.
///
/// # Safety
///
/// This function crosses the C ABI boundary but takes no raw pointers. Callers
/// must serialize initialization with any concurrent backend/model operations;
/// llama.cpp global initialization is process-wide.
#[no_mangle]
pub unsafe extern "C" fn nano_backend_init() -> i32 {
    match init_backend() {
        Ok(_) => 0,
        Err(_) => -1,
    }
}

/// Load a GGUF model from disk.
/// Returns opaque pointer to NanoModel, or NULL on failure.
///
/// # Safety
///
/// `path` must be a valid, non-null, NUL-terminated C string that remains valid
/// for the duration of this call. The returned pointer, when non-null, is owned
/// by the caller and must be released exactly once with `nano_model_free` after
/// all contexts created from it have been freed.
#[no_mangle]
pub unsafe extern "C" fn nano_model_load(path: *const c_char, n_gpu_layers: i32) -> *mut NanoModel {
    if path.is_null() {
        return std::ptr::null_mut();
    }
    let c_str = CStr::from_ptr(path);
    let path_str = match c_str.to_str() {
        Ok(s) => s,
        Err(_) => return std::ptr::null_mut(),
    };

    let params = ModelLoadParams {
        gpu_layers: n_gpu_layers,
        ..Default::default()
    };

    match NanoModel::load(path_str, &params) {
        Ok(model) => Box::into_raw(Box::new(model)),
        Err(_) => std::ptr::null_mut(),
    }
}

/// Free a loaded NanoModel instance.
///
/// # Safety
///
/// `model` must be either null or a pointer returned by `nano_model_load` that
/// has not already been freed. Every `NanoContext` created from this model must
/// be freed before this call because contexts hold llama.cpp pointers into
/// model-owned memory.
#[no_mangle]
pub unsafe extern "C" fn nano_model_free(model: *mut NanoModel) {
    if !model.is_null() {
        let _ = Box::from_raw(model);
    }
}

/// Base address + size (bytes) of the model's primary mmap.
/// Returns NULL + *size=0 if not mmap'd. For NanoRuntime layer streaming.
///
/// # Safety
/// `model` must be a valid, non-null pointer returned by `nano_model_load`.
#[no_mangle]
pub unsafe extern "C" fn nano_model_mmap_addr(
    model: *const NanoModel,
    size: *mut usize,
) -> *mut std::ffi::c_void {
    if model.is_null() {
        if !size.is_null() {
            *size = 0;
        }
        return std::ptr::null_mut();
    }
    let (addr, sz) = (*model).mmap_addr();
    if !size.is_null() {
        *size = sz;
    }
    addr
}

/// Create an inference context for a loaded model.
/// Returns opaque pointer to NanoContext, or NULL on failure.
///
/// # Safety
///
/// `model` must be a valid, non-null pointer returned by `nano_model_load` and
/// must outlive the returned context. The returned pointer, when non-null, is
/// owned by the caller and must be released exactly once with
/// `nano_context_free` before the model is freed.
#[no_mangle]
pub unsafe extern "C" fn nano_context_create(
    model: *const NanoModel,
    ctx_size: u32,
) -> *mut NanoContext {
    if model.is_null() {
        return std::ptr::null_mut();
    }
    let model_ref = &*model;
    let size = if ctx_size == 0 { 2048 } else { ctx_size };
    let params = ModelLoadParams {
        context_size: size,
        ..Default::default()
    };

    match model_ref.create_context(&params) {
        Ok(ctx) => Box::into_raw(Box::new(ctx)),
        Err(_) => std::ptr::null_mut(),
    }
}

/// Free an inference context instance.
///
/// # Safety
///
/// `ctx` must be either null or a pointer returned by `nano_context_create`
/// that has not already been freed. No other thread may be using the context
/// while it is being freed.
#[no_mangle]
pub unsafe extern "C" fn nano_context_free(ctx: *mut NanoContext) {
    if !ctx.is_null() {
        let _ = Box::from_raw(ctx);
    }
}

/// Generate text synchronously from a prompt.
/// Returns null-terminated C string allocated on heap. Free with nano_string_free().
///
/// # Safety
///
/// `ctx` must be a valid, mutable pointer returned by `nano_context_create`.
/// `model` must be a valid pointer returned by `nano_model_load` and must be the
/// same model used to create `ctx`. `prompt` must be a valid, non-null,
/// NUL-terminated C string for the duration of this call. Callers must not use
/// the same context concurrently. The returned pointer, when non-null, must be
/// released exactly once with `nano_string_free`.
#[no_mangle]
pub unsafe extern "C" fn nano_generate(
    ctx: *mut NanoContext,
    model: *const NanoModel,
    prompt: *const c_char,
    max_tokens: u32,
    temperature: f32,
    top_p: f32,
) -> *mut c_char {
    if ctx.is_null() || model.is_null() || prompt.is_null() {
        return std::ptr::null_mut();
    }

    let ctx_ref = &mut *ctx;
    let model_ref = &*model;
    let c_str = CStr::from_ptr(prompt);
    let prompt_str = match c_str.to_str() {
        Ok(s) => s,
        Err(_) => return std::ptr::null_mut(),
    };

    let params = GenerateParams {
        max_tokens: max_tokens as usize,
        temperature,
        top_p,
        ..Default::default()
    };

    match ctx_ref.generate(model_ref, prompt_str, &params, None) {
        Ok(res) => match CString::new(res.text) {
            Ok(c_out) => c_out.into_raw(),
            Err(_) => std::ptr::null_mut(),
        },
        Err(_) => std::ptr::null_mut(),
    }
}

/// Free a C string allocated by nano_generate().
///
/// # Safety
///
/// `str_ptr` must be either null or a pointer returned by `nano_generate` that
/// has not already been freed. Passing any other pointer, including string
/// literals or memory allocated by another allocator, is undefined behavior.
#[no_mangle]
pub unsafe extern "C" fn nano_string_free(str_ptr: *mut c_char) {
    if !str_ptr.is_null() {
        let _ = CString::from_raw(str_ptr);
    }
}
