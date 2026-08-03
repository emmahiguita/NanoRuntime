/* nanortime_streaming.h — C header for CacheAwareLoader FFI
 *
 * Include this in llama.cpp when NANORTIME_STREAMING is defined.
 * Link against libnanortime_streaming.a
 *
 * Usage in llama.cpp:
 *   #ifdef NANORTIME_STREAMING
 *   #include "nanortime_streaming.h"
 *   #endif
 */

#ifndef NANORTIME_STREAMING_H
#define NANORTIME_STREAMING_H

#ifdef __cplusplus
extern "C" {
#endif

#include <stddef.h>

/* Initialize the streaming loader.
 * @param gguf_path    Path to the GGUF model file
 * @param window_layers Number of layers to keep in the active window (2-3)
 * @return             Total number of layers on success, -1 to -4 on error
 */
int nanortime_streaming_init(const char* gguf_path, int window_layers);

/* Load a layer into the sliding window.
 * @param layer_idx    0-based layer index
 * @return             Pointer to layer weights, or NULL on error
 */
void* nanortime_streaming_load(int layer_idx);

/* Release the current window. Forces MADV_DONTNEED + MADV_PAGEOUT. */
void nanortime_streaming_release(int layer_idx);

/* Get current VMA size in bytes. */
unsigned long nanortime_streaming_vma_bytes(void);

/* Check if the device can safely stream this model.
 * @param total_layers   Total layers in the model
 * @param window_layers  Window size
 * @param ram_total_mb   Device total RAM in MB
 * @return               1 if viable, 0 if not
 */
int nanortime_streaming_can_run(int total_layers, int window_layers, unsigned long ram_total_mb);

/* Get the total number of layers. */
int nanortime_streaming_layer_count(void);

#ifdef __cplusplus
}
#endif

#endif /* NANORTIME_STREAMING_H */
