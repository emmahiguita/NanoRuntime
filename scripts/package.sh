#!/bin/bash
# scripts/package.sh — Empaqueta NanoAI para distribución
# Uso: ./scripts/package.sh [VERSION]

set -euo pipefail

VERSION="${1:-0.1.0}"
PLATFORM="$(uname -s | tr '[:upper:]' '[:lower:]')"
ARCH="$(uname -m)"

echo "======================================"
echo " Packaging NanoAI v$VERSION"
echo " Platform: $PLATFORM-$ARCH"
echo "======================================"

# Build in release mode
echo "[1/4] Building release binary..."
cargo build --release

# Create distribution directory
DIST_DIR="dist/nanortime-$VERSION-$PLATFORM-$ARCH"
rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR"

# Copy binary
echo "[2/4] Copying files..."
cp target/release/nanortime "$DIST_DIR/" 2>/dev/null || \
cp target/release/nanortime.exe "$DIST_DIR/" 2>/dev/null || \
cp target/release/nanortime-cli "$DIST_DIR/" 2>/dev/null || true

# Copy config and assets
cp nano.manifest.json "$DIST_DIR/"
cp .env.example "$DIST_DIR/"
cp -r tools "$DIST_DIR/" 2>/dev/null || mkdir -p "$DIST_DIR/tools"
mkdir -p "$DIST_DIR/models"
mkdir -p "$DIST_DIR/data"
mkdir -p "$DIST_DIR/logs"

# Create README
cat > "$DIST_DIR/README.md" << EOF
# NanoAI Runtime v$VERSION

Hybrid Edge-Cloud AI Orchestration Engine

## Quick Start

1. Download a GGUF model (e.g., Qwen2.5-7B-Instruct-Q4_K_M.gguf)
2. Place it in the \`models/\` directory
3. Edit \`nano.manifest.json\` to point to your model
4. Run: \`./nanortime\` for interactive chat

## Documentation

Full docs: https://github.com/nanoai/nanortime

## License

MIT License
EOF

# Generate checksums
echo "[3/4] Generating checksums..."
cd "$DIST_DIR"
if command -v sha256sum &> /dev/null; then
    sha256sum * > SHA256SUMS.txt
elif command -v shasum &> /dev/null; then
    shasum -a 256 * > SHA256SUMS.txt
fi
cd - > /dev/null

# Create archive
echo "[4/4] Creating archive..."
cd dist
tar -czf "nanortime-$VERSION-$PLATFORM-$ARCH.tar.gz" "nanortime-$VERSION-$PLATFORM-$ARCH/"
cd - > /dev/null

echo ""
echo "Done! Archive: dist/nanortime-$VERSION-$PLATFORM-$ARCH.tar.gz"
echo "Checksums:   dist/nanortime-$VERSION-$PLATFORM-$ARCH/SHA256SUMS.txt"
