/*
 * nanortime_streaming_patch.h — Parche quirúrgico para llama.cpp
 *
 * COPIA este archivo a llama.cpp/include/nanortime_streaming_patch.h
 * e inclúyelo en src/llama.cpp con:
 *   #ifdef NANORTIME_STREAMING
 *   #include "nanortime_streaming_patch.h"
 *   #endif
 *
 * Sin NANORTIME_STREAMING definido, llama.cpp es 100% upstream.
 * Con el flag, las capas se cargan desde el CacheAwareLoader de Rust.
 */

#ifndef NANORTIME_STREAMING_PATCH_H
#define NANORTIME_STREAMING_PATCH_H

#ifdef __cplusplus
extern "C" {
#endif

/* Funciones FFI expuestas por nanortime_core (Rust staticlib) */
void* nanortime_streaming_load(int layer_idx);
void  nanortime_streaming_release(int layer_idx);
int   nanortime_streaming_init(const char* path, int window);
unsigned long nanortime_streaming_vma_bytes(void);
int   nanortime_streaming_layer_count(void);

#ifdef __cplusplus
}
#endif

/*
 * INTEGRACIÓN EN llama.cpp:
 *
 * 1) En llama_model_load_from_file(), después de abrir el archivo y
 *    ANTES de crear el mmap completo:
 *
 *    #ifdef NANORTIME_STREAMING
 *    // NanoRuntime: streaming en vez de mmap completo.
 *    // Baja VMA de 7,891 MB a ~494 MB (Fórmula 5 del Memory Model).
 *    static int g_stream_total = 0;
 *    g_stream_total = nanortime_streaming_init(model_path, 2);
 *    if (g_stream_total < 0) {
 *        // Fallback a mmap normal si el streaming falla
 *        LLAMA_LOG_ERROR("NanoRuntime streaming init failed: %d\n", g_stream_total);
 *    } else {
 *        LLAMA_LOG_INFO("NanoRuntime streaming: %d layers, VMA < 800 MB\n", g_stream_total);
 *        goto streaming_skip_mmap;
 *    }
 *    #endif
 *
 * 2) En el decode loop (llama_decode_internal), por cada capa:
 *
 *    #ifdef NANORTIME_STREAMING
 *    // Cargar pesos de esta capa desde la ventana del loader
 *    void* layer_ptr = nanortime_streaming_load(layer_idx);
 *    if (!layer_ptr) { return -1; }
 *    // Usar layer_ptr como base para los tensores de esta capa
 *    #endif
 *
 *    /* ... forward pass normal de la capa ... */
 *
 *    #ifdef NANORTIME_STREAMING
 *    // Liberar la capa después de procesarla (MADV_DONTNEED)
 *    nanortime_streaming_release(layer_idx);
 *    #endif
 */

#endif /* NANORTIME_STREAMING_PATCH_H */
