#!/usr/bin/env bash
# NanoRuntime V1 — release gates (smoke reproducible).
# Corre clippy + tests Rust (feature simulated) y analyze + tests de gates Flutter.
# El hardware real (PSS/TTFT/termal) se verifica manualmente en OPPO/Android.
set -euo pipefail

echo "== Rust: clippy -D warnings (core + cli, simulated) =="
cargo clippy -p nanortime-core --features simulated -- -D warnings
cargo clippy -p nanortime-cli --features simulated -- -D warnings

echo "== Rust: tests core (simulated) + server =="
cargo test -p nanortime-core --features simulated
cargo test -p nanortime-cli --features simulated server

echo "== Flutter: analyze + tests de gates =="
cd products/nanoMOBILE/flutter_app
flutter analyze
flutter test \
  test/chat_cancel_test.dart \
  test/chat_timings_test.dart \
  test/chat_tier_gate_test.dart \
  test/chat_soak_test.dart

echo ""
echo "✅ release gates V1 verdes — baseline congelado (nanoruntime-v1.0)"
