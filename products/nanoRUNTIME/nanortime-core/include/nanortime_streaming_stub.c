/* nanortime_streaming_stub.c — Minimal C implementation of CacheAwareLoader FFI.
 *
 * Provides the 6 symbols declared in nanortime_streaming.h.
 * Uses mmap + madvise to manage a sliding window of model layers.
 *
 * Compile with: -DNANORTIME_STREAMING
 * Link into llama.cpp's llama-cli binary.
 */

#include "nanortime_streaming.h"

#include <fcntl.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <unistd.h>

/* ── Internal state ───────────────────────────────────────────────── */

static struct {
    int      fd;              /* GGUF file descriptor */
    void *   map;             /* full file mmap */
    size_t   file_size;       /* total file size in bytes */
    int      total_layers;    /* number of layers in model */
    int      window_layers;   /* max layers kept in active window */
    int      current_window_start; /* first layer currently in window */
    int      initialized;
} g_stream = { -1, NULL, 0, 0, 0, 0, 0 };

/* ── GGUF helpers (minimal) ───────────────────────────────────────── */

/* Estimate layer count from file size. Accurate enough for mmap windowing.
 * Typical models: 1.5B ~1GB/28L, 3B ~1.7GB/32L, 7B ~2.8GB/32L */
static int count_layers_from_size(void) {
    size_t mb = g_stream.file_size / (1024 * 1024);
    if (mb > 4000) return 40;   /* 14B+ */
    if (mb > 2500) return 32;   /* 7B */
    if (mb > 1500) return 28;   /* 3B */
    if (mb > 800)  return 28;   /* 1.5B */
    return 24;                   /* <1B */
}

/* ── Auto-init: extract model path from /proc/self/cmdline ────────── */

static void auto_init_from_cmdline(void) {
    if (g_stream.initialized) return;

    /* Read /proc/self/cmdline to find --model or -m argument.
     * cmdline is null-separated on Linux/Android. */
    int fd = open("/proc/self/cmdline", O_RDONLY);
    if (fd < 0) return;

    char buf[4096];
    ssize_t n = read(fd, buf, sizeof(buf) - 1);
    close(fd);
    if (n <= 0) return;
    buf[n] = '\0';

    /* Parse null-separated arguments looking for -m or --model */
    char * arg = buf;
    while (arg < buf + n) {
        if (strcmp(arg, "-m") == 0 || strcmp(arg, "--model") == 0) {
            arg += strlen(arg) + 1;
            if (arg < buf + n && arg[0] != '-') {
                fprintf(stderr, "NanoRuntime: auto-detected model path: %s\n", arg);
                nanortime_streaming_init(arg, 3);
                return;
            }
        }
        arg += strlen(arg) + 1;
    }
}

/* ── Public API ───────────────────────────────────────────────────── */

int nanortime_streaming_init(const char * gguf_path, int window_layers) {
    if (g_stream.initialized) return g_stream.total_layers;

    g_stream.fd = open(gguf_path, O_RDONLY);
    if (g_stream.fd < 0) {
        perror("NanoRuntime: open");
        return -1;
    }

    struct stat st;
    if (fstat(g_stream.fd, &st) != 0) {
        perror("NanoRuntime: fstat");
        close(g_stream.fd);
        return -2;
    }
    g_stream.file_size = (size_t)st.st_size;

    /* mmap the full file with MAP_PRIVATE so MADV_DONTNEED works */
    g_stream.map = mmap(NULL, g_stream.file_size, PROT_READ,
                        MAP_PRIVATE, g_stream.fd, 0);
    if (g_stream.map == MAP_FAILED) {
        perror("NanoRuntime: mmap");
        close(g_stream.fd);
        return -3;
    }

    /* Advise sequential access for efficient readahead */
    madvise(g_stream.map, g_stream.file_size, MADV_SEQUENTIAL);

    /* Preload first window_layers into page cache (async readahead).
     * This eliminates cold-start latency — layers are already in RAM
     * when the first graph_compute fires. */
    {
        size_t layer_size  = g_stream.file_size / g_stream.total_layers;
        size_t window_bytes = layer_size * g_stream.window_layers;
        if (window_bytes < g_stream.file_size) {
            madvise(g_stream.map, window_bytes, MADV_WILLNEED);
            /* Also tell the kernel to start async readahead from disk */
            posix_fadvise(g_stream.fd, 0, (off_t)window_bytes, POSIX_FADV_WILLNEED);
        }
    }

    g_stream.total_layers   = count_layers_from_size();
    g_stream.window_layers  = window_layers > 0 ? window_layers : 3;
    g_stream.current_window_start = 0;
    g_stream.initialized    = 1;

    fprintf(stderr, "NanoRuntime: streaming init OK (%d layers, window=%d, file=%zu MB)\n",
            g_stream.total_layers, g_stream.window_layers,
            g_stream.file_size / (1024 * 1024));
    return g_stream.total_layers;
}

void * nanortime_streaming_load(int layer_idx) {
    /* Auto-initialize on first call by reading model path from cmdline */
    auto_init_from_cmdline();

    if (!g_stream.initialized) return NULL;
    if (layer_idx < 0 || layer_idx >= g_stream.total_layers) return NULL;

    /* Slide window if needed */
    int needed_start = layer_idx - (g_stream.window_layers - 1);
    if (needed_start < 0) needed_start = 0;

    /* Evict layers that fell out of the window */
    for (int i = g_stream.current_window_start; i < needed_start && i < g_stream.total_layers; i++) {
        /* Mark evicted pages as no longer needed */
        size_t layer_size = g_stream.file_size / g_stream.total_layers;
        size_t layer_off  = (size_t)i * layer_size;
        if (layer_off < g_stream.file_size) {
            madvise((char *)g_stream.map + layer_off, layer_size, MADV_DONTNEED);
        }
    }

    /* Prefetch the new window into page cache */
    size_t layer_size = g_stream.file_size / g_stream.total_layers;
    for (int i = needed_start; i <= layer_idx && i < g_stream.total_layers; i++) {
        size_t layer_off = (size_t)i * layer_size;
        if (layer_off < g_stream.file_size) {
            madvise((char *)g_stream.map + layer_off, layer_size, MADV_WILLNEED);
        }
    }

    g_stream.current_window_start = needed_start;

    /* Return a pointer into the mmap (caller treats as opaque) */
    size_t offset = (size_t)layer_idx * (g_stream.file_size / g_stream.total_layers);
    if (offset >= g_stream.file_size) return NULL;
    return (char *)g_stream.map + offset;
}

void nanortime_streaming_release(int layer_idx) {
    if (!g_stream.initialized) return;
    if (layer_idx < 0 || layer_idx >= g_stream.total_layers) return;

    /* Evict layer from page cache so RAM stays free for next layers.
     * MADV_DONTNEED: mark pages as reclaimable. Kernel will drop them
     * under memory pressure or immediately if no other references. */
    size_t layer_size = g_stream.file_size / g_stream.total_layers;
    size_t layer_off  = (size_t)layer_idx * layer_size;
    if (layer_off < g_stream.file_size) {
        madvise((char *)g_stream.map + layer_off, layer_size, MADV_DONTNEED);
    }
}

unsigned long nanortime_streaming_vma_bytes(void) {
    if (!g_stream.initialized) return 0;
    /* Return the size of the active window (what we told the kernel to keep) */
    return (unsigned long)(g_stream.file_size / g_stream.total_layers)
           * g_stream.window_layers;
}

int nanortime_streaming_can_run(int total_layers, int window_layers,
                                 unsigned long ram_total_mb) {
    if (total_layers <= 0 || window_layers <= 0) return 0;
    /* Need enough RAM for: window_layers worth of model + KV cache + OS */
    size_t layer_mb = g_stream.file_size / (1024 * 1024) / total_layers;
    size_t needed_mb = (size_t)window_layers * layer_mb + 256; /* 256 MB for KV cache */
    return (ram_total_mb > needed_mb) ? 1 : 0;
}

int nanortime_streaming_layer_count(void) {
    return g_stream.initialized ? g_stream.total_layers : 0;
}
