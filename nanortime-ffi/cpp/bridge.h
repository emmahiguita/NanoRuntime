// nanortime-ffi bridge header
// C++ bridge between Rust and llama.cpp
//
// This file defines the C-compatible API that the Rust FFI bindings call.
// Functions wrap llama.cpp's C++ API in a flat C interface.

#ifndef NANORTIME_BRIDGE_H
#define NANORTIME_BRIDGE_H

#include <cstdint>
#include <cstddef>

#ifdef __cplusplus
extern "C" {
#endif

// Opaque handles
typedef void* nanortime_model_t;
typedef void* nanortime_context_t;

// Backend lifecycle
int nanortime_backend_init(void);
void nanortime_backend_free(void);

// Model management
nanortime_model_t nanortime_load_model(
    const char* path,
    int context_size,
    int gpu_layers,
    int use_mmap
);
void nanortime_free_model(nanortime_model_t model);

// Context management
nanortime_context_t nanortime_create_context(
    nanortime_model_t model,
    int context_size,
    int threads,
    int batch_size
);
void nanortime_free_context(nanortime_context_t ctx);

// Tokenization
int nanortime_tokenize(
    nanortime_context_t ctx,
    const char* text,
    int add_bos,
    int* tokens_out,
    int max_tokens
);

// Inference
int nanortime_eval(
    nanortime_context_t ctx,
    const int* tokens,
    int n_tokens,
    int n_past,
    float* logits_out,
    int logits_size
);

// Model info
int nanortime_vocab_size(nanortime_context_t ctx);
int nanortime_context_size(nanortime_context_t ctx);
int nanortime_embedding_size(nanortime_context_t ctx);

// Token conversion
int nanortime_token_to_str(
    nanortime_context_t ctx,
    int token_id,
    char* output,
    int output_size
);

#ifdef __cplusplus
}
#endif

#endif // NANORTIME_BRIDGE_H
