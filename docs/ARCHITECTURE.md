# NanoRuntime Architecture

NanoRuntime se organiza como motor primero, plataformas después. Flutter no es el producto completo; es el cliente mobile oficial.

## Capas

```text
Core Engine Layer
  products/nanoRUNTIME/nanortime-core/ # Rust puro: orquestador, memoria, routing, privacidad, RAG

Inference Backend
  products/nanoRUNTIME/nanortime-ffi/  # FFI hacia llama.cpp / GGUF
  vendor/llama-cpp-sys-2/  # binding vendorizado

Platform Bridge
  products/nanoRUNTIME/nanortime-cli/  # CLI, HTTP/SSE compatible con llama.cpp
  products/nanoRUNTIME/nanortime-web/  # entrypoint web/server Rust
  server/                  # telemetría FastAPI para desarrollo/observabilidad

Product Interfaces
  products/nanoMOBILE/flutter_app/     # Flutter UI + Android nativo/JNI/C++

Research Tooling
  scripts/                 # benchmarks, papers, validación
  docs/                    # reportes y ADRs
```

## Reglas de frontera

- `nanortime-core` no puede depender de Flutter, Android, FastAPI ni scripts.
- Flutter puede depender del runtime solo por FFI/JNI/HTTP/CLI, no por acceso directo a internals Rust.
- Android/Kotlin/C++ dentro de `products/nanoMOBILE/flutter_app/android` pertenece a la plataforma mobile, no al core.
- Python/FastAPI es observabilidad/dev telemetry, no runtime core.
- `scripts/` no define comportamiento de producción.

## Comparación correcta

- Runtime: NanoRuntime vs llama.cpp, MLC-LLM, PowerInfer, ExecuTorch.
- Mobile UI: Flutter vs Kotlin nativo, Swift, React Native.
- Telemetry server: FastAPI exporter vs Prometheus/custom backend.
- CLI: `nanortime` vs `llama-cli`.

## Refactor policy

Separación incremental. No big-bang. Todo cambio debe preservar contratos públicos, lifecycle, threading, ownership y comportamiento observable.
