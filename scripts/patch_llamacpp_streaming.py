#!/usr/bin/env python3
"""
patch_llamacpp_streaming.py — Aplica el hook NANORTIME_STREAMING a llama.cpp.

Modifica llama.cpp para que, cuando se compila con -DNANORTIME_STREAMING,
cargue los pesos de cada capa desde el CacheAwareLoader de NanoRuntime
en lugar de asumir que todo el modelo esta en RAM (mmap completo).

USO: python3 patch_llamacpp_streaming.py <ruta_a_llama.cpp>

El parche hace 2 cosas:
  1. Inserta el #include del header FFI al inicio
  2. Inserta el hook load/release AROUND del decode de cada capa
     (envuelve la llamada a ggml_backend_sched_graph_compute)

Los cambios son CONDICIONALES (#ifdef NANORTIME_STREAMING):
  - Sin el flag, llama.cpp es 100% upstream.
  - Con el flag, invoca nanortime_streaming_* via FFI.
"""

import sys
from pathlib import Path

def patch_header(content: str) -> str:
    """Inserta el include del header FFI al inicio del archivo."""
    header_insert = '''
#ifdef NANORTIME_STREAMING
#include "nanortime_streaming.h"
static int g_stream_current_layer = -1;
#endif
'''
    first_include = content.find("#include")
    if first_include >= 0:
        return content[:first_include] + header_insert + "\n" + content[first_include:]
    return header_insert + "\n" + content

def patch_decode_loop(content: str) -> str:
    """Inserta hooks load/release alrededor del graph compute.

    Busca la linea:
        auto status = ggml_backend_sched_graph_compute_async(...);
    Inserta load ANTES y release DESPUES del bloque de error.
    """
    import re

    # Match: the full compute + error check block
    # auto status = ggml_backend_sched_graph_compute_async(sched.get(), gf);
    # if (status != GGML_STATUS_SUCCESS) {
    #     LLAMA_LOG_ERROR(...);
    # }
    pattern = (
        r'(auto\s+status\s*=\s*ggml_backend_sched_graph_compute_async\s*\([^;]*\)\s*;)'
        r'(\s*if\s*\(status\s*!=\s*GGML_STATUS_SUCCESS\)\s*\{[^}]*\})'
    )

    m = re.search(pattern, content, re.DOTALL)
    if not m:
        print(f"[WARN] No se encontro el bloque graph_compute_async + error check")
        return content

    compute_line = m.group(1)  # auto status = ggml_backend_sched_graph_compute_async(...);
    error_block = m.group(2)   # if (status != ...) { ... }

    load_hook = '''
#ifdef NANORTIME_STREAMING
    // NanoRuntime: cargar pesos de capa actual desde ventana de streaming
    if (g_stream_current_layer >= 0) {
        void* layer_ptr = nanortime_streaming_load(g_stream_current_layer);
        if (!layer_ptr) {
            LLAMA_LOG_ERROR("NanoRuntime: failed to load layer %d\\n", g_stream_current_layer);
        }
    }
#endif
'''

    release_hook = '''
#ifdef NANORTIME_STREAMING
    // NanoRuntime: liberar capa procesada (MADV_DONTNEED)
    if (g_stream_current_layer >= 0) {
        nanortime_streaming_release(g_stream_current_layer);
    }
#endif
'''

    replacement = load_hook + '\n    ' + compute_line + '\n' + error_block + '\n' + release_hook
    content = content[:m.start()] + replacement + content[m.end():]

    print(f"[OK] Decode hook insertado (load antes, release despues del error check)")
    return content

def patch_graph_callback(content: str) -> str:
    """Inserta g_stream_current_layer = il en el graph callback.
    
    El callback en llama_context::graph_get_cb() recibe int il (layer index).
    Insertamos g_stream_current_layer = il dentro de if (il >= 0) { ... }
    para que los hooks load/release sepan que capa se esta computando.
    """
    marker = "if (il >= 0) {"
    if marker not in content:
        print("[WARN] No se encontro 'if (il >= 0) {' en graph_get_cb")
        return content
    
    # Insert layer tracking right after the if (il >= 0) {
    hook = '''if (il >= 0) {
#ifdef NANORTIME_STREAMING
            g_stream_current_layer = il;
#endif'''
    content = content.replace(marker, hook, 1)  # Only first occurrence
    print("[OK] Layer tracker insertado en graph_get_cb")
    return content


def main():
    if len(sys.argv) < 2:
        print("USO: python3 patch_llamacpp_streaming.py <ruta_a_llama-context.cpp>")
        sys.exit(1)

    target = Path(sys.argv[1])
    if not target.exists():
        print(f"[ERROR] No se encontro {target}")
        sys.exit(1)

    content = target.read_text(encoding="utf-8", errors="ignore")

    # 1. Insertar el include FFI
    content = patch_header(content)

    # 2. Insertar el hook de decode
    content = patch_decode_loop(content)

    # 3. Insertar el tracker de capa en el graph callback
    content = patch_graph_callback(content)

    # 4. Silenciar el progress callback en llama.cpp
    content = patch_progress_callback(content)

    # 5. Escribir el archivo modificado
    target.write_text(content, encoding="utf-8")
    print(f"[OK] {target} parcheado con NANORTIME_STREAMING")
    print("[OK] Compilar con: -DNANORTIME_STREAMING para activar")
    print("[OK] Sin el flag, llama.cpp es 100% upstream")


def patch_progress_callback(content: str) -> str:
    """Silencia el progress callback que imprime puntos a stdout.
    
    Inserta un return true temprano bajo NANORTIME_STREAMING.
    El callback sigue existiendo pero no imprime nada.
    """
    marker = "[](float progress, void * ctx) {"
    if marker not in content:
        print("[WARN] No se encontro el progress callback en llama.cpp")
        return content
    
    hook = '''[](float progress, void * ctx) {
#ifdef NANORTIME_STREAMING
            // NanoRuntime: no-op (los dots saturan eMMC)
            (void)progress; (void)ctx;
            return true;
#endif'''
    content = content.replace(marker, hook, 1)
    print("[OK] Progress callback silenciado")
    return content
    """Fuerza tty_can_use_colors() = false bajo NANORTIME_STREAMING.
    
    Esto elimina spinners, barras de progreso, y caracteres de control
    que saturan el I/O cuando stdout/stderr van a archivo en vez de TTY.
    """
    marker = 'bool tty_can_use_colors() {'
    if marker not in content:
        print("[WARN] No se encontro tty_can_use_colors() en common.cpp")
        return content

    hook = '''bool tty_can_use_colors() {
#ifdef NANORTIME_STREAMING
    // NanoRuntime: siempre modo no-TTY (evita spinners que saturan eMMC)
    return false;
#else'''
    content = content.replace(marker, hook, 1)
    print("[OK] tty_can_use_colors() forzado a false (no spinners)")
    return content

if __name__ == "__main__":
    main()
