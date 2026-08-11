# nanoMOBILE

Producto mobile de NanoAI.

```text
nanoMOBILE/
└── flutter_app/
    ├── lib/      # Flutter/Dart organizado por features y capas
    └── android/  # integración Android nativa: MethodChannels, JNI, VNC, PTY
```

`nanoMOBILE` consume NanoRuntime como producto externo. No contiene crates Rust del runtime.
