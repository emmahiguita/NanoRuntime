// nanortime-ffi bridge implementation
// C++ bridge between Rust and llama.cpp
//
// This file implements the C-compatible API declared in bridge.h.
// It wraps llama.cpp's internal C++ structures and functions.
//
// NOTE: This is a skeleton. Uncomment llama.cpp includes and replace
// placeholder implementations when llama.cpp submodule is available.

#include "bridge.h"

#include <cstring>
#include <cstdio>

// When llama.cpp is available, include:
// #include "llama.h"
// #include "ggml.h"

// ── Backend lifecycle ──────────────────────────────────────────

int nanortime_backend_init(void) {
    // When llama.cpp is available:
    // llama_backend_init();
    fprintf(stderr, "[nanortime-ffi] Backend initialized (simulated)\n");
    return 0;
}

void nanortime_backend_free(void) {
    // llama_backend_free();
    fprintf(stderr, "[nanortime-ffi] Backend freed (simulated)\n");
}

// ── Model management ───────────────────────────────────────────

nanortime_model_t nanortime_load_model(
    const char* path,
    int context_size,
    int gpu_layers,
    int use_mmap)
{
    if (!path || !*path) {
        return nullptr;
    }

    fprintf(stderr, "[nanortime-ffi] Loading model: %s\n", path);

    // When llama.cpp is available:
    // struct llama_model_params params = llama_model_default_params();
    // params.n_gpu_layers = gpu_layers;
    // params.use_mmap = use_mmap;
    // return (nanortime_model_t)llama_load_model_from_file(path, params);

    // Placeholder: return non-null to simulate success
    return (nanortime_model_t)(uintptr_t)0xDEADBEEF;
}

void nanortime_free_model(nanortime_model_t model) {
    if (model) {
        // llama_free_model((struct llama_model*)model);
        fprintf(stderr, "[nanortime-ffi] Model freed\n");
    }
}

// ── Context management ─────────────────────────────────────────

nanortime_context_t nanortime_create_context(
    nanortime_model_t model,
    int context_size,
    int threads,
    int batch_size)
{
    if (!model) {
        return nullptr;
    }

    fprintf(stderr, "[nanortime-ffi] Creating context: ctx=%d, threads=%d\n",
            context_size, threads);

    // When llama.cpp is available:
    // struct llama_context_params params = llama_context_default_params();
    // params.n_ctx = context_size;
    // params.n_threads = threads;
    // params.n_batch = batch_size;
    // return (nanortime_context_t)llama_new_context((struct llama_model*)model, params);

    return (nanortime_context_t)(uintptr_t)0xCAFEBABE;
}

void nanortime_free_context(nanortime_context_t ctx) {
    if (ctx) {
        // llama_free((struct llama_context*)ctx);
        fprintf(stderr, "[nanortime-ffi] Context freed\n");
    }
}

// ── Tokenization ───────────────────────────────────────────────

int nanortime_tokenize(
    nanortime_context_t ctx,
    const char* text,
    int add_bos,
    int* tokens_out,
    int max_tokens)
{
    if (!ctx || !text || !tokens_out) {
        return -1;
    }

    // When llama.cpp is available:
    // return llama_tokenize((struct llama_context*)ctx, text, tokens_out, max_tokens, add_bos);

    // Placeholder: create simple word-based tokens
    const char* p = text;
    int count = 0;
    const char* word_start = p;

    while (*p && count < max_tokens) {
        // Skip whitespace
        while (*p == ' ' || *p == '\n' || *p == '\t') p++;

        if (!*p) break;

        // Find end of word
        word_start = p;
        while (*p && *p != ' ' && *p != '\n' && *p != '\t') p++;

        // Assign a simple token ID (hash-like)
        int hash = 0;
        for (const char* q = word_start; q < p; q++) {
            hash = hash * 31 + (unsigned char)*q;
        }
        tokens_out[count++] = (hash & 0x7FFFFFFF) % 32000 + 1;
    }

    return count;
}

// ── Inference ──────────────────────────────────────────────────

int nanortime_eval(
    nanortime_context_t ctx,
    const int* tokens,
    int n_tokens,
    int n_past,
    float* logits_out,
    int logits_size)
{
    if (!ctx || !tokens || !logits_out) {
        return -1;
    }

    // When llama.cpp is available:
    // llama_eval((struct llama_context*)ctx, tokens, n_tokens, n_past, threads);
    // float* logits = llama_get_logits((struct llama_context*)ctx);
    // int vocab = llama_n_vocab((struct llama_context*)ctx);
    // memcpy(logits_out, logits, sizeof(float) * (vocab < logits_size ? vocab : logits_size));

    // Placeholder: fill with dummy logits
    for (int i = 0; i < logits_size && i < 100; i++) {
        // Bias: first few tokens get higher logits (simulates non-uniform distribution)
        logits_out[i] = (float)(100 - i) / 100.0f;
    }

    return 0;
}

// ── Model info ─────────────────────────────────────────────────

int nanortime_vocab_size(nanortime_context_t ctx) {
    if (!ctx) return -1;
    // return llama_n_vocab((struct llama_context*)ctx);
    return 32000;
}

int nanortime_context_size(nanortime_context_t ctx) {
    if (!ctx) return -1;
    // return llama_n_ctx((struct llama_context*)ctx);
    return 8192;
}

int nanortime_embedding_size(nanortime_context_t ctx) {
    if (!ctx) return -1;
    // return llama_n_embd((struct llama_context*)ctx);
    return 4096;
}

int nanortime_token_to_str(
    nanortime_context_t ctx,
    int token_id,
    char* output,
    int output_size)
{
    if (!ctx || !output) return -1;
    // return llama_token_to_str((struct llama_context*)ctx, token_id, output, output_size);
    snprintf(output, output_size, "[token_%d]", token_id);
    return 0;
}
