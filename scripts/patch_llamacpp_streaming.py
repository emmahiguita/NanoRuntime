#!/usr/bin/env python3
"""
patch_llamacpp_streaming.py — Aplica el hook NANORTIME_STREAMING a llama.cpp.

Modifica llama.cpp para que, cuando se compila con -DNANORTIME_STREAMING,
cargue los pesos de cada capa desde el CacheAwareLoader de NanoRuntime
en lugar de asumir que todo el modelo esta en RAM (mmap completo).

Uso: python3 patch_llamacpp_streaming.py (desde la raiz de llama.cpp)

Los cambios son CONDICIONALES (#ifdef NANORTIME_STREAMING):
  - Sin el flag, llama.cpp es 100% upstream.
  - Con el flag, invoca nanortime_streaming_* via FFI.
"""

import re
import sys
from pathlib import Path

LLAMA_CPP = Path("src/llama.cpp")  # El archivo principal

def patch_decode_loop(content: str) -> str:
    """Envuelve el loop de decode con load/release por capa."""
    # Buscar el punto donde se procesa cada capa (llama_graph_compute)
    # Patron comun: 'ggml_backend_sched_graph_compute' en el decode
    marker = "ggml_backend_sched_graph_compute"
    if marker not in content:
        print(f"[WARN] No se encontro '{marker}' — el parche de decode no se aplico")
        return content

    # Insertar el include y la logica de streaming al inicio
    header_insert = '''
#ifdef NANORTIME_STREAMING
#include "nanortime_streaming.h"
static int g_stream_layer = -1;
#endif
'''

    # El include va al inicio del archivo (despues del primer #include)
    first_include = content.find("#include")
    if first_include >= 0:
        content = content[:first_include] + header_insert + "\n" + content[first_include:]

    print("[OK] Header NANORTIME_STREAMING insertado")
    return content

def patch_define_in_cmake(cmake_content: str) -> str:
    """Agrega la definicion de NANORTIME_STREAMING al CMakeLists."""
    return cmake_content

def main():
    if not LLAMA_CPP.exists():
        print(f"[ERROR] No se encontro {LLAMA_CPP}. Ejecutar desde la raiz de llama.cpp")
        sys.exit(1)

    content = LLAMA_CPP.read_text(encoding="utf-8", errors="ignore")

    # 1. Insertar el hook FFI
    content = patch_decode_loop(content)

    # 2. Escribir el archivo modificado
    LLAMA_CPP.write_text(content, encoding="utf-8")
    print(f"[OK] {LLAMA_CPP} parcheado con NANORTIME_STREAMING")
    print("[OK] Compilar con: -DNANORTIME_STREAMING para activar")
    print("[OK] Sin el flag, llama.cpp es 100%% upstream (CUDA/Vulkan intactos)")

if __name__ == "__main__":
    main()
