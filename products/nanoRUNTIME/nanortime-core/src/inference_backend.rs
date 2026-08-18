//! InferenceBackend trait — Dependency Inversion for model backends.
//!
//! `ModelManager` depends on this trait, not on concrete `nanortime_ffi` types.
//! Swapping llama.cpp for ONNX, ExecuTorch, or NNAPI requires only a new impl,
//! not changes to the orchestration layer.

use std::fmt::Debug;

/// Parameters for loading a model into memory.
#[derive(Debug, Clone)]
pub struct BackendLoadParams {
    pub context_size: u32,
    pub gpu_layers: i32,
    pub use_mmap: bool,
    pub threads: u32,
    pub batch_size: u32,
}

/// Parameters controlling generation behavior.
#[derive(Debug, Clone)]
pub struct BackendGenerateParams {
    pub max_tokens: usize,
    pub temperature: f32,
    pub top_p: f32,
    pub repeat_penalty: f32,
    pub stop_sequences: Vec<String>,
}

/// Result of a generation call.
#[derive(Debug, Clone, Default)]
pub struct BackendGenerateResult {
    pub text: String,
    pub token_probabilities: Vec<f32>,
    /// Gate R10 — tiempo hasta el primer token, ms.
    pub ttft_ms: u64,
    /// Gate R10 — tiempo de prefill (procesado del prompt), ms.
    pub prefill_ms: u64,
    /// Gate R10 — tokens del prompt reutilizados del KV cache (prefix hit).
    pub cache_hit_tokens: usize,
    /// Gate R10 — tokens totales procesados.
    pub total_tokens: usize,
}

/// Streaming token callback: (token_text, probability, is_stop).
/// Returning `false` aborts generation early (result is the partial text).
pub type TokenCallback = dyn FnMut(&str, f32, bool) -> bool + Send;

/// Abstraction over model inference backends (llama.cpp, ONNX, ExecuTorch, etc.).
///
/// # Safety
/// Implementations must ensure that `Model` outlives any `Context` created
/// from it, and that `Context` is not used concurrently across threads
/// unless the implementation explicitly supports it.
pub trait InferenceBackend: Send + Sync {
    type Model: Send;
    type Context;
    type LoraAdapter: Send;

    /// Load a GGUF model from disk. Returns opaque model handle.
    fn load_model(path: &str, params: &BackendLoadParams) -> Result<Self::Model, String>;

    /// Create a fresh inference context. Each generation should use
    /// a new context to avoid KV cache contamination.
    fn create_context(
        model: &Self::Model,
        params: &BackendLoadParams,
    ) -> Result<Self::Context, String>;

    /// Number of tokens in the model's vocabulary.
    fn n_vocab(model: &Self::Model) -> usize;

    /// Number of transformer layers in the model (0 if unknown).
    fn n_layer(model: &Self::Model) -> usize;

    /// Chat template from GGUF metadata (None for base models).
    fn chat_template(model: &Self::Model) -> Option<String>;

    /// Token type produced by the backend.
    type Token: Copy + Debug;

    /// Tokenize text with optional BOS token.
    ///
    /// SRP: separa tokenización del decode. El prefix cache tokeniza prefix y
    /// turno por separado (`add_bos=true` solo en el prefix; el turno no debe
    /// re-añadir BOS o la secuencia de tokens se corrompe).
    fn tokenize(model: &Self::Model, text: &str, add_bos: bool)
        -> Result<Vec<Self::Token>, String>;

    /// Prefill puro: decodifica tokens en el KV sin sampler.
    ///
    /// `need_logits` pone logits en el último token (para muestrear después).
    /// Retorna el número de tokens procesados. SRP: prefill ≠ generación.
    fn decode_prompt(
        ctx: &mut Self::Context,
        tokens: &[Self::Token],
        need_logits: bool,
    ) -> Result<usize, String>;

    /// Generate text (blocking, synchronous).
    fn generate(
        ctx: &mut Self::Context,
        model: &Self::Model,
        prompt: &str,
        params: &BackendGenerateParams,
        lora: Option<&mut Self::LoraAdapter>,
    ) -> Result<BackendGenerateResult, String>;

    /// Generate text with per-token streaming callback.
    fn generate_streaming(
        ctx: &mut Self::Context,
        model: &Self::Model,
        prompt: &str,
        params: &BackendGenerateParams,
        lora: Option<&mut Self::LoraAdapter>,
        on_token: &mut TokenCallback,
    ) -> Result<BackendGenerateResult, String>;

    /// Load a LoRA adapter onto the model.
    fn load_lora(
        model: &Self::Model,
        path: &str,
        strength: f32,
    ) -> Result<Self::LoraAdapter, String>;

    /// Save KV cache state to a session file. Returns bytes written.
    fn save_state(ctx: &Self::Context, path: &str) -> Result<usize, String>;

    /// Restore KV cache state from a session file. Returns tokens loaded.
    fn load_state(ctx: &mut Self::Context, path: &str) -> Result<usize, String>;

    /// Size of the saved state in bytes (informational).
    fn state_size(ctx: &Self::Context) -> usize;

    /// Generate text embeddings for semantic search.
    fn embed_text(model: &Self::Model, text: &str) -> Result<Vec<f32>, String>;
}

// ── Concrete LlamaCpp implementation ──

/// LlamaCpp backend via nanortime-ffi/llama-cpp-2.
pub struct LlamaCppBackend;

impl InferenceBackend for LlamaCppBackend {
    type Model = nanortime_ffi::NanoModel;
    type Context = nanortime_ffi::NanoContext;
    type LoraAdapter = nanortime_ffi::NanoLoraAdapter;
    type Token = nanortime_ffi::LlamaToken;

    fn load_model(path: &str, params: &BackendLoadParams) -> Result<Self::Model, String> {
        let lp = nanortime_ffi::ModelLoadParams {
            context_size: params.context_size,
            gpu_layers: params.gpu_layers,
            use_mmap: params.use_mmap,
            threads: params.threads,
            batch_size: params.batch_size,
        };
        nanortime_ffi::NanoModel::load(path, &lp)
    }

    fn create_context(
        model: &Self::Model,
        params: &BackendLoadParams,
    ) -> Result<Self::Context, String> {
        let lp = nanortime_ffi::ModelLoadParams {
            context_size: params.context_size,
            gpu_layers: params.gpu_layers,
            use_mmap: params.use_mmap,
            threads: params.threads,
            batch_size: params.batch_size,
        };
        model.create_context(&lp)
    }

    fn n_vocab(model: &Self::Model) -> usize {
        model.n_vocab() as usize
    }

    fn n_layer(model: &Self::Model) -> usize {
        model.n_layer() as usize
    }

    fn chat_template(model: &Self::Model) -> Option<String> {
        model.chat_template()
    }

    fn tokenize(
        model: &Self::Model,
        text: &str,
        add_bos: bool,
    ) -> Result<Vec<Self::Token>, String> {
        model.tokenize(text, add_bos)
    }

    fn decode_prompt(
        ctx: &mut Self::Context,
        tokens: &[Self::Token],
        need_logits: bool,
    ) -> Result<usize, String> {
        ctx.decode_prompt(tokens, need_logits)
    }

    fn generate(
        ctx: &mut Self::Context,
        model: &Self::Model,
        prompt: &str,
        params: &BackendGenerateParams,
        lora: Option<&mut Self::LoraAdapter>,
    ) -> Result<BackendGenerateResult, String> {
        let gp = nanortime_ffi::GenerateParams {
            max_tokens: params.max_tokens,
            temperature: params.temperature,
            top_p: params.top_p,
            repeat_penalty: params.repeat_penalty,
            stop_sequences: params.stop_sequences.clone(),
        };
        let r = ctx.generate(model, prompt, &gp, lora)?;
        Ok(BackendGenerateResult {
            text: r.text,
            token_probabilities: r.token_probabilities,
            ttft_ms: r.ttft_ms,
            prefill_ms: r.prefill_ms,
            cache_hit_tokens: r.cache_hit_tokens,
            total_tokens: r.total_tokens,
        })
    }

    fn generate_streaming(
        ctx: &mut Self::Context,
        model: &Self::Model,
        prompt: &str,
        params: &BackendGenerateParams,
        lora: Option<&mut Self::LoraAdapter>,
        on_token: &mut TokenCallback,
    ) -> Result<BackendGenerateResult, String> {
        let gp = nanortime_ffi::GenerateParams {
            max_tokens: params.max_tokens,
            temperature: params.temperature,
            top_p: params.top_p,
            repeat_penalty: params.repeat_penalty,
            stop_sequences: params.stop_sequences.clone(),
        };
        let r = ctx.generate_streaming(model, prompt, &gp, lora, |text, prob, stop| {
            on_token(text, prob, stop)
        })?;
        Ok(BackendGenerateResult {
            text: r.text,
            token_probabilities: r.token_probabilities,
            ttft_ms: r.ttft_ms,
            prefill_ms: r.prefill_ms,
            cache_hit_tokens: r.cache_hit_tokens,
            total_tokens: r.total_tokens,
        })
    }

    fn load_lora(
        model: &Self::Model,
        path: &str,
        strength: f32,
    ) -> Result<Self::LoraAdapter, String> {
        model.load_lora(path, strength)
    }

    fn save_state(ctx: &Self::Context, path: &str) -> Result<usize, String> {
        ctx.save_state(path)
    }

    fn load_state(ctx: &mut Self::Context, path: &str) -> Result<usize, String> {
        ctx.load_state(path)
    }

    fn state_size(ctx: &Self::Context) -> usize {
        ctx.state_size()
    }

    fn embed_text(model: &Self::Model, text: &str) -> Result<Vec<f32>, String> {
        let backend = nanortime_ffi::get_backend();
        model.embed_text(text, backend)
    }
}
