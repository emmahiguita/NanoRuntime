#!/usr/bin/env bash
# build_android.sh — build reproducible del PIE `nanortime` para Android.
#
# La toolchain completa (NDK, linker API 26, ar, CC/CXX y rustflags
# +neon,+dotprod,+fp16) vive en .cargo/config.toml del repo — este script
# NO redefine variables: usa la config del repo como fuente de verdad.
#
# Requisitos:
#   - rustup target add aarch64-linux-android
#   - Android NDK en $LOCALAPPDATA/Android/Sdk/ndk/28.2.13676358
#     (o el path indicado en .cargo/config.toml)
#
# Uso:
#   bash products/nanoRUNTIME/build_android.sh            # release (default)
#   bash products/nanoRUNTIME/build_android.sh --debug
#
# Salida: copia el binario a
#   products/nanoMOBILE/flutter_app/assets/bin/nanortime
# y verifica ELF aarch64 + PIE (Type: DYN) con llvm-readelf del NDK.
set -euo pipefail

PROFILE="release"
[[ "${1:-}" == "--debug" ]] && PROFILE="debug"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

TARGET="aarch64-linux-android"
echo "==> cargo build -p nanortime-cli --target $TARGET --$PROFILE"
cargo build -p nanortime-cli --target "$TARGET" --"$PROFILE"

TARGET_DIR="${CARGO_TARGET_DIR:-target}"
BIN="$REPO_ROOT/$TARGET_DIR/$TARGET/$PROFILE/nanortime"
[[ -f "$BIN" ]] || { echo "ERROR: binario no generado en $BIN"; exit 1; }

# Verificación: ELF aarch64 + PIE. Prefiere llvm-readelf del NDK del config.
READELF="${LOCALAPPDATA:-}/Android/Sdk/ndk/28.2.13676358/toolchains/llvm/prebuilt/windows-x86_64/bin/llvm-readelf.exe"
[[ -f "$READELF" ]] || READELF="llvm-readelf"

echo "==> Verificación ELF:"
"$READELF" -h "$BIN" | grep -E "Class:|Machine:|Type:" || {
  echo "WARN: llvm-readelf no disponible — verificar PIE manualmente"; }

DEST="$REPO_ROOT/products/nanoMOBILE/flutter_app/assets/bin"
mkdir -p "$DEST"
cp "$BIN" "$DEST/nanortime"
echo "OK: $DEST/nanortime"
