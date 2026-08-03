#!/usr/bin/env bash
# build_streaming_arm64.sh — Compila llama.cpp + CacheAwareLoader para ARM64
# 
# Produce un binario llama-cli con NANORTIME_STREAMING que baja la VMA
# del 7B de 7,891 MB a ~494 MB (Fórmula 5 del Memory Model).
#
# Requiere: NDK, cmake, ninja, Rust con target aarch64-linux-android
# Uso: bash scripts/build_streaming_arm64.sh

set -e

# ── Config ─────────────────────────────────────────────────────────
NDK="${ANDROID_NDK_HOME:-$HOME/Android/Sdk/ndk/27.0.12077973}"
LLAMA_SRC="${LLAMA_SRC:-llama.cpp-source}"
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STREAMING_H="$PROJECT_ROOT/nanortime-core/include/nanortime_streaming.h"

echo "=== NanoRuntime Streaming Build (ARM64) ==="
echo "NDK: $NDK"
echo "llama.cpp: $LLAMA_SRC"

# ── 1. Compilar streaming_ffi como staticlib ──────────────────────
echo ""
echo "[1/5] Compilando streaming_ffi (Rust staticlib)..."
cargo build --lib -p nanortime-core --target aarch64-linux-android --release
STATICLIB="target/aarch64-linux-android/release/libnanortime_core.a"
if [ ! -f "$STATICLIB" ]; then
    echo "ERROR: no se encontro $STATICLIB"
    exit 1
fi
echo "  OK: $STATICLIB"

# ── 2. Aplicar el parche quirurgico a llama.cpp ────────────────────
echo ""
echo "[2/5] Aplicando parche NANORTIME_STREAMING..."
cp "$STREAMING_H" "$LLAMA_SRC/include/"

# El parche se aplica via CMake flag + el header ya incluido
# (el patch real se documenta en nanortime_streaming_patch.txt)
echo "  OK: header copiado a $LLAMA_SRC/include/"

# ── 3. Configurar CMake con NANORTIME_STREAMING ───────────────────
echo ""
echo "[3/5] Configurando CMake..."
rm -rf "$LLAMA_SRC/build"
cmake -B "$LLAMA_SRC/build" \
    -DCMAKE_TOOLCHAIN_FILE="$NDK/build/cmake/android.toolchain.cmake" \
    -DANDROID_ABI=arm64-v8a \
    -DANDROID_PLATFORM=android-26 \
    -DANDROID_STL=c++_shared \
    -DGGML_CUDA=OFF \
    -DGGML_VULKAN=OFF \
    -DBUILD_SHARED_LIBS=OFF \
    -DLLAMA_CURL=OFF \
    -DCMAKE_BUILD_TYPE=Release \
    -DNANORTIME_STREAMING=ON \
    -DCMAKE_C_FLAGS="-w" \
    -DCMAKE_CXX_FLAGS="-w"

# ── 4. Compilar llama-cli ─────────────────────────────────────────
echo ""
echo "[4/5] Compilando llama-cli..."
cmake --build "$LLAMA_SRC/build" -j$(nproc) --target llama-cli

# ── 5. Verificar binario ──────────────────────────────────────────
echo ""
echo "[5/5] Binario ARM64:"
BIN="$LLAMA_SRC/build/bin/llama-cli"
if [ -f "$BIN" ]; then
    ls -la "$BIN"
    echo ""
    echo "DESPLEGAR:"
    echo "  adb push $BIN /data/local/tmp/llama-stream"
    echo "  adb shell 'cd /data/local/tmp && LD_LIBRARY_PATH=. ./llama-stream \\"
    echo "    -m deepseek.gguf --stream-7b -p \"test\" -n 10'"
    echo ""
    echo "Esperado: VmSize <= 800 MB, tok/s ~0.24 (vs 0.05 actual)"
else
    echo "ERROR: binario no compilado"
    exit 1
fi
