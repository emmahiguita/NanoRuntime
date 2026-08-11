# nanoRUNTIME

Producto runtime de NanoAI.

```text
nanoRUNTIME/
├── nanortime-core/  # orquestación, memoria, routing, herramientas
├── nanortime-ffi/   # C-ABI/JNI bridge hacia llama.cpp
├── nanortime-cli/   # CLI + HTTP/SSE server
└── nanortime-web/   # entrypoint web Rust
```

No debe importar ni depender de Flutter, Android UI ni código de `nanoMOBILE`.
