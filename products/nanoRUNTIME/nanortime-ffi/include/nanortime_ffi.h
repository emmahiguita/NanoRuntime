#ifndef NANORTIME_FFI_H
#define NANORTIME_FFI_H

#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

// Opaque handles
typedef struct NanoModel NanoModel;
typedef struct NanoContext NanoContext;

/**
 * Initialise the llama.cpp backend. Must be called once before any model loading.
 * @return 0 on success, -1 on failure.
 */
int32_t nano_backend_init(void);

/**
 * Load a GGUF model from disk.
 * @param path Null-terminated UTF-8 path to the .gguf model file.
 * @param n_gpu_layers Number of layers to offload to GPU (0 for CPU-only).
 * @return Pointer to NanoModel handle, or NULL on error.
 */
NanoModel* nano_model_load(const char* path, int32_t n_gpu_layers);

/**
 * Free a loaded NanoModel handle.
 * @param model Pointer to NanoModel instance.
 */
void nano_model_free(NanoModel* model);

/**
 * Create an inference context for a loaded model.
 * @param model Pointer to valid NanoModel instance.
 * @param ctx_size Context window size in tokens (0 defaults to 2048).
 * @return Pointer to NanoContext handle, or NULL on error.
 */
NanoContext* nano_context_create(const NanoModel* model, uint32_t ctx_size);

/**
 * Free an inference context instance.
 * @param ctx Pointer to NanoContext instance.
 */
void nano_context_free(NanoContext* ctx);

/**
 * Generate text synchronously from a prompt.
 * @param ctx Pointer to active NanoContext instance.
 * @param model Pointer to active NanoModel instance.
 * @param prompt Null-terminated UTF-8 prompt string.
 * @param max_tokens Maximum number of tokens to generate.
 * @param temperature Temperature sampling (e.g. 0.7).
 * @param top_p Top-p nucleus sampling (e.g. 0.9).
 * @return Null-terminated heap-allocated C string containing the output. Must be freed with nano_string_free().
 */
char* nano_generate(
    NanoContext* ctx,
    const NanoModel* model,
    const char* prompt,
    uint32_t max_tokens,
    float temperature,
    float top_p
);

/**
 * Free a C string returned by nano_generate().
 * @param str_ptr Pointer to the string returned by nano_generate().
 */
void nano_string_free(char* str_ptr);

#ifdef __cplusplus
}
#endif

#endif // NANORTIME_FFI_H
