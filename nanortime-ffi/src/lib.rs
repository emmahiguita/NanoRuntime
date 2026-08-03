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

/// No-op callback that swallows all llama.cpp log output.
unsafe extern "C" fn noop_llama_log(
    _level: i32,
    _text: *const std::ffi::c_char,
    _user_data: *mut std::ffi::c_void,
) {
    // Discard all log messages from llama.cpp
}

static BACKEND: OnceLock<LlamaBackend> = OnceLock::new();

pub fn init_backend() -> Result<(), String> {
    BACKEND.get_or_init(|| {
        // Suppress llama.cpp log output BEFORE initializing backend.
        // This eliminates "load:", "repack:", "sched_reserve:", etc. from stderr.
        unsafe {
            llama_log_set(Some(noop_llama_log), std::ptr::null_mut());
        }
        LlamaBackend::init().expect("Failed to init llama.cpp backend")
    });
    Ok(())
}

/// Returns a reference to the initialized backend.
/// Must call init_backend() first.
pub fn get_backend() -> &'static LlamaBackend {
    BACKEND.get().expect("Backend not initialized. Call init_backend() first.")
}

pub struct NanoModel {
    // Box::leak'd to get 'static lifetime required by LlamaContext
    inner: &'static mut LlamaModel,
    #[allow(dead_code)]
    path: String,
}

// SAFETY: llama.cpp allows using a model from any single thread.
// We control concurrent access via ModelManager's RwLock.
unsafe impl Send for NanoModel {}
unsafe impl Sync for NanoModel {}

pub struct NanoContext {
    inner: llama_cpp_2::context::LlamaContext<'static>,
    context_size: u32,
}

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
        Self { context_size: 8192, gpu_layers: 0, use_mmap: true, threads: 4, batch_size: 512 }
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
            max_tokens: 2048, temperature: 0.7, top_p: 0.9, repeat_penalty: 1.1,
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
    pub fn load(path: &str, _params: &ModelLoadParams) -> Result<Self, String> {
        init_backend()?;
        let backend = BACKEND.get().unwrap();
        let model_path = Path::new(path);
        if !model_path.exists() {
            return Err(format!("Model file not found: {}", path));
        }
        let model_params = LlamaModelParams::default();
        let inner = LlamaModel::load_from_file(backend, model_path, &model_params)
            .map_err(|e| format!("Failed to load model '{}': {}", path, e))?;
        let inner: &'static mut LlamaModel = Box::leak(Box::new(inner));
        tracing::info!("Loaded model: {} ({} vocab)", path, inner.n_vocab());
        Ok(Self { inner, path: path.to_string() })
    }

    pub fn create_context(&self, params: &ModelLoadParams) -> Result<NanoContext, String> {
        init_backend()?;
        let backend = BACKEND.get().unwrap();
        let ctx_params = LlamaContextParams::default()
            .with_n_ctx(NonZeroU32::new(params.context_size))
            .with_n_batch(params.batch_size);
        let inner = self.inner.new_context(backend, ctx_params)
            .map_err(|e| format!("Failed to create context: {}", e))?;
        // SAFETY: self.inner is 'static (Box::leak'd). The returned context borrows
        // from the model which lives for the duration of the process.
        let inner: llama_cpp_2::context::LlamaContext<'static> = unsafe {
            std::mem::transmute(inner)
        };
        tracing::info!("Created context: {} tokens, {} batch", params.context_size, params.batch_size);
        Ok(NanoContext { inner, context_size: params.context_size })
    }

    pub fn tokenize(&self, text: &str, add_bos: bool) -> Result<Vec<LlamaToken>, String> {
        let bos = if add_bos { AddBos::Always } else { AddBos::Never };
        self.inner.str_to_token(text, bos)
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

    pub fn n_vocab(&self) -> i32 { self.inner.n_vocab() }

    pub fn estimate_tokens(text: &str) -> usize { text.len().div_ceil(4) }

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

        let ctx = self.inner.new_context(backend, ctx_params)
            .map_err(|e| format!("Failed to create embedding context: {}", e))?;

        // SAFETY: model lives for process duration
        let mut ctx: llama_cpp_2::context::LlamaContext<'static> = unsafe {
            std::mem::transmute(ctx)
        };

        // Tokenize
        let tokens = self.inner.str_to_token(text, AddBos::Always)
            .map_err(|e| format!("Tokenization failed: {}", e))?;

        if tokens.is_empty() {
            return Err("Empty tokenization result".to_string());
        }

        // Process all tokens (no generation needed)
        let mut n_past = 0i32;
        for chunk in tokens.chunks(512) {
            let mut batch = LlamaBatch::new(chunk.len(), 1);
            for (i, &token) in chunk.iter().enumerate() {
                batch.add(token, n_past + i as i32, &[0], false)
                    .map_err(|e| format!("Batch add: {}", e))?;
            }
            ctx.decode(&mut batch)
                .map_err(|e| format!("Decode: {}", e))?;
            n_past += chunk.len() as i32;
        }

        // Get embedding for last sequence (position 0, seq 0)
        let emb = ctx.embeddings_ith(0)
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
        let adapter = self.inner.lora_adapter_init(lora_path)
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

impl NanoContext {
    pub fn generate(
        &mut self, model: &NanoModel, prompt: &str, params: &GenerateParams,
        mut lora: Option<&mut NanoLoraAdapter>,
    ) -> Result<GenerateResult, String> {
        let start = std::time::Instant::now();

        // Apply LoRA adapter if provided (scope ensures borrow released after)
        let had_lora = lora.is_some();
        if had_lora {
            // We know it's Some from the check above; unwrap is safe.
            let adapter: &mut NanoLoraAdapter = lora.as_mut().unwrap();
            self.inner.lora_adapter_set(&mut adapter.0, 1.0)
                .map_err(|e| format!("Failed to apply LoRA: {:?}", e))?;
            tracing::debug!("LoRA adapter applied");
        }

        // ── Tokenization and generation ──────────────────────

        let tokens = model.tokenize(prompt, true)?;
        let n_prompt = tokens.len();
        if tokens.is_empty() { return Err("Empty prompt".to_string()); }

        let mut n_past: i32 = 0;

        // Process prompt: all tokens except last (no logits), then last with logits.
        if tokens.len() == 1 {
            let mut batch = LlamaBatch::new(1, 1);
            batch.add(tokens[0], 0, &[0], true)
                .map_err(|e| format!("Batch add: {}", e))?;
            self.inner.decode(&mut batch)
                .map_err(|e| format!("Decode: {}", e))?;
            n_past = 1;
        } else {
            let (prompt_tokens, last_tok) = tokens.split_at(tokens.len() - 1);

            for chunk in prompt_tokens.chunks(512) {
                let mut batch = LlamaBatch::new(chunk.len(), 1);
                for (i, &token) in chunk.iter().enumerate() {
                    batch.add(token, n_past + i as i32, &[0], false)
                        .map_err(|e| format!("Batch add: {}", e))?;
                }
                self.inner.decode(&mut batch)
                    .map_err(|e| format!("Decode: {}", e))?;
                n_past += chunk.len() as i32;
            }

            let mut batch = LlamaBatch::new(1, 1);
            batch.add(last_tok[0], n_past, &[0], true)
                .map_err(|e| format!("Batch add: {}", e))?;
            self.inner.decode(&mut batch)
                .map_err(|e| format!("Decode: {}", e))?;
            n_past += 1;
        }

        // Manual temperature sampling using raw logits.
        // Avoids LlamaSampler::temp() crash on Windows (llama-cpp-sys-2 v0.1.153 bug).
        let eos = model.token_eos();
        let mut output = String::new();
        let mut token_probs = Vec::with_capacity(params.max_tokens);
        let mut rng = rand::thread_rng();

        // Sample first generated token from logits at batch position 0.
        let logits = self.inner.get_logits_ith(0);
        let first_token = sample_token(logits, params.temperature, params.top_p, &mut rng);
        let mut last_token = first_token;

        if first_token != eos {
            let probs = apply_temperature_and_softmax(logits, params.temperature);
            let prob = probs.get(first_token.0 as usize).copied().unwrap_or(0.5);
            token_probs.push(prob);

            let piece = model.token_to_text(first_token)?;
            let should_stop = params.stop_sequences.iter().any(|s| piece.contains(s));
            if !should_stop {
                output.push_str(&piece);
            }
        }

        // Generate remaining tokens one at a time: add → decode → sample
        for _ in 1..params.max_tokens {
            if last_token == eos { break; }
            if n_past as u32 >= self.context_size { break; }

            let mut batch = LlamaBatch::new(1, 1);
            batch.add(last_token, n_past, &[0], true)
                .map_err(|e| format!("Batch add: {}", e))?;
            self.inner.decode(&mut batch)
                .map_err(|e| format!("Decode: {}", e))?;
            n_past += 1;

            let logits = self.inner.get_logits_ith(0);
            let token = sample_token(logits, params.temperature, params.top_p, &mut rng);
            last_token = token;
            if token == eos { break; }

            let probs = apply_temperature_and_softmax(logits, params.temperature);
            let prob = probs.get(token.0 as usize).copied().unwrap_or(0.5);
            token_probs.push(prob);

            let piece = model.token_to_text(token)?;
            let mut check = output.clone();
            check.push_str(&piece);
            if params.stop_sequences.iter().any(|s| check.contains(s)) { break; }

            output.push_str(&piece);
        }

        let elapsed = start.elapsed().as_secs_f64();
        let tps = if elapsed > 0.0 { n_prompt as f64 / elapsed } else { 0.0 };

        // Remove LoRA adapter if it was applied
        if had_lora {
            let adapter: &mut NanoLoraAdapter = lora.as_mut().unwrap();
            let _ = self.inner.lora_adapter_remove(&mut adapter.0);
            tracing::debug!("LoRA adapter removed");
        }

        Ok(GenerateResult {
            text: output,
            token_probabilities: token_probs,
            tokens_generated: n_past as usize - n_prompt,
            tokens_per_second: tps,
        })
    }

    pub fn context_size(&self) -> u32 { self.context_size }

    // ── Session Persistence (KV cache state) ────────────────────
    // Guarda/restaura el estado completo (KV cache) para eliminar
    // la espera de prefill en la siguiente sesión. Byte-idéntico.

    /// Tamaño del estado del contexto (KV cache) en bytes.
    pub fn state_size(&self) -> usize {
        self.inner.get_state_size()
    }

    /// Guarda el estado (KV cache) a un archivo.
    ///
    /// Devuelve el número de bytes escritos.
    pub fn save_state(&self, path: &str) -> Result<usize, String> {
        // state_save_file necesita los tokens; guardamos con lista vacía
        // (el estado del KV cache se persiste, los tokens se re-tokenizan)
        let tokens: Vec<LlamaToken> = Vec::new();
        self.inner
            .state_save_file(path, &tokens)
            .map_err(|e| format!("Failed to save state: {:?}", e))?;
        Ok(self.inner.get_state_size())
    }

    /// Restaura el estado (KV cache) desde un archivo.
    ///
    /// Devuelve el número de tokens restaurados (0 si la lista estaba vacía).
    pub fn load_state(&mut self, path: &str) -> Result<usize, String> {
        let tokens = self
            .inner
            .state_load_file(path, self.context_size as usize)
            .map_err(|e| format!("Failed to load state: {:?}", e))?;
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
    /// El callback recibe (token_text, probability, is_stop).
    /// Retorna el texto completo generado.
    pub fn generate_streaming(
        &mut self, model: &NanoModel, prompt: &str, params: &GenerateParams,
        mut lora: Option<&mut NanoLoraAdapter>,
        mut on_token: impl FnMut(&str, f32, bool),
    ) -> Result<GenerateResult, String> {
        let start = std::time::Instant::now();

        // Apply LoRA adapter if provided
        let had_lora = lora.is_some();
        if had_lora {
            let adapter: &mut NanoLoraAdapter = lora.as_mut().unwrap();
            self.inner.lora_adapter_set(&mut adapter.0, 1.0)
                .map_err(|e| format!("Failed to apply LoRA: {:?}", e))?;
        }

        // Tokenization and prompt processing (same as generate)
        let tokens = model.tokenize(prompt, true)?;
        let n_prompt = tokens.len();
        if tokens.is_empty() { return Err("Empty prompt".to_string()); }

        let mut n_past: i32 = 0;

        if tokens.len() == 1 {
            let mut batch = LlamaBatch::new(1, 1);
            batch.add(tokens[0], 0, &[0], true)
                .map_err(|e| format!("Batch add: {}", e))?;
            self.inner.decode(&mut batch)
                .map_err(|e| format!("Decode: {}", e))?;
            n_past = 1;
        } else {
            let (prompt_tokens, last_tok) = tokens.split_at(tokens.len() - 1);
            for chunk in prompt_tokens.chunks(512) {
                let mut batch = LlamaBatch::new(chunk.len(), 1);
                for (i, &token) in chunk.iter().enumerate() {
                    batch.add(token, n_past + i as i32, &[0], false)
                        .map_err(|e| format!("Batch add: {}", e))?;
                }
                self.inner.decode(&mut batch)
                    .map_err(|e| format!("Decode: {}", e))?;
                n_past += chunk.len() as i32;
            }
            let mut batch = LlamaBatch::new(1, 1);
            batch.add(last_tok[0], n_past, &[0], true)
                .map_err(|e| format!("Batch add: {}", e))?;
            self.inner.decode(&mut batch)
                .map_err(|e| format!("Decode: {}", e))?;
            n_past += 1;
        }

        let eos = model.token_eos();
        let mut output = String::new();
        let mut token_probs = Vec::with_capacity(params.max_tokens);
        let mut rng = rand::thread_rng();

        // Sample first token
        let logits = self.inner.get_logits_ith(0);
        let first_token = sample_token(logits, params.temperature, params.top_p, &mut rng);
        let mut last_token = first_token;

        if first_token != eos {
            let probs = apply_temperature_and_softmax(logits, params.temperature);
            let prob = probs.get(first_token.0 as usize).copied().unwrap_or(0.5);
            token_probs.push(prob);

            let piece = model.token_to_text(first_token)?;
            let should_stop = params.stop_sequences.iter().any(|s| piece.contains(s));
            if !should_stop {
                output.push_str(&piece);
                on_token(&piece, prob, false);
            }
        }

        // Generate remaining tokens
        for _ in 1..params.max_tokens {
            if last_token == eos { break; }
            if n_past as u32 >= self.context_size { break; }

            let mut batch = LlamaBatch::new(1, 1);
            batch.add(last_token, n_past, &[0], true)
                .map_err(|e| format!("Batch add: {}", e))?;
            self.inner.decode(&mut batch)
                .map_err(|e| format!("Decode: {}", e))?;
            n_past += 1;

            let logits = self.inner.get_logits_ith(0);
            let token = sample_token(logits, params.temperature, params.top_p, &mut rng);
            last_token = token;
            if token == eos {
                on_token("", 1.0, true);
                break;
            }

            let probs = apply_temperature_and_softmax(logits, params.temperature);
            let prob = probs.get(token.0 as usize).copied().unwrap_or(0.5);
            token_probs.push(prob);

            let piece = model.token_to_text(token)?;
            let mut check = output.clone();
            check.push_str(&piece);
            if params.stop_sequences.iter().any(|s| check.contains(s)) { break; }

            output.push_str(&piece);
            on_token(&piece, prob, false);
        }

        let elapsed = start.elapsed().as_secs_f64();
        let tps = if elapsed > 0.0 { n_prompt as f64 / elapsed } else { 0.0 };

        // Remove LoRA adapter if it was applied
        if had_lora {
            let adapter: &mut NanoLoraAdapter = lora.as_mut().unwrap();
            let _ = self.inner.lora_adapter_remove(&mut adapter.0);
        }

        Ok(GenerateResult {
            text: output,
            token_probabilities: token_probs,
            tokens_generated: n_past as usize - n_prompt,
            tokens_per_second: tps,
        })
    }
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
        let (idx, _) = logits.iter().enumerate()
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

    let inv_temp = if temperature > 0.0 { 1.0 / temperature } else { 1.0 };

    // Numerically stable softmax: subtract max before exp
    let max_logit = logits.iter().cloned()
        .fold(f32::NEG_INFINITY, f32::max);

    let exps: Vec<f32> = logits.iter()
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
    let mut indexed: Vec<(i32, f32)> = probs.iter().enumerate()
        .map(|(i, &p)| (i as i32, p))
        .collect();

    // Sort by probability descending
    indexed.sort_by(|a, b| b.1.partial_cmp(&a.1).unwrap_or(std::cmp::Ordering::Equal));

    // Find the cutoff where cumulative probability >= top_p
    let mut cumulative = 0.0;
    let cutoff_idx = indexed.iter().position(|(_, p)| {
        cumulative += *p;
        cumulative >= top_p
    }).unwrap_or(indexed.len() - 1);

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
#[no_mangle]
pub unsafe extern "C" fn nano_backend_init() -> i32 {
    match init_backend() {
        Ok(_) => 0,
        Err(_) => -1,
    }
}

/// Load a GGUF model from disk.
/// Returns opaque pointer to NanoModel, or NULL on failure.
#[no_mangle]
pub unsafe extern "C" fn nano_model_load(
    path: *const c_char,
    n_gpu_layers: i32,
) -> *mut NanoModel {
    if path.is_null() { return std::ptr::null_mut(); }
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
#[no_mangle]
pub unsafe extern "C" fn nano_model_free(model: *mut NanoModel) {
    if !model.is_null() {
        let _ = Box::from_raw(model);
    }
}

/// Create an inference context for a loaded model.
/// Returns opaque pointer to NanoContext, or NULL on failure.
#[no_mangle]
pub unsafe extern "C" fn nano_context_create(
    model: *const NanoModel,
    ctx_size: u32,
) -> *mut NanoContext {
    if model.is_null() { return std::ptr::null_mut(); }
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
#[no_mangle]
pub unsafe extern "C" fn nano_context_free(ctx: *mut NanoContext) {
    if !ctx.is_null() {
        let _ = Box::from_raw(ctx);
    }
}

/// Generate text synchronously from a prompt.
/// Returns null-terminated C string allocated on heap. Free with nano_string_free().
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
        Ok(res) => {
            match CString::new(res.text) {
                Ok(c_out) => c_out.into_raw(),
                Err(_) => std::ptr::null_mut(),
            }
        },
        Err(_) => std::ptr::null_mut(),
    }
}

/// Free a C string allocated by nano_generate().
#[no_mangle]
pub unsafe extern "C" fn nano_string_free(str_ptr: *mut c_char) {
    if !str_ptr.is_null() {
        let _ = CString::from_raw(str_ptr);
    }
}

