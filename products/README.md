# Products

Producto separados por responsabilidad.

```text
products/
├── nanoRUNTIME/  # Runtime Rust: core, FFI, CLI, web/server
└── nanoMOBILE/   # App mobile Flutter + Android native
```

Regla de arquitectura: `nanoRUNTIME` no depende de `nanoMOBILE`. La app mobile consume runtime por HTTP/JNI/canales nativos definidos, no por imports cruzados de código.
