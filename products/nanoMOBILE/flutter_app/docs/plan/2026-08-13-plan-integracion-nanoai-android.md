# Plan Maestro — Integración NanoAI alrededor de Android

Fecha: 2026-08-13
Commit base: `18f8227` (master) — "fix: escritorio Linux completo — framebuffer con aspect del device, escalas 1:1, wallpaper por aspect"
Alcance: auditar e integrar las piezas existentes (Flutter, Kotlin, C, Rust, Linux) en un producto Android local-first con tres modos: Access, Assistant, Pro/Linux.

---

## 0. Estado del repositorio

- Rama `master`, HEAD `18f8227` (2026-08-13). Repo git raíz: `Nanoai/` (incluye `products/nanoRUNTIME/` y `products/nanoMOBILE/flutter_app/`).
- Cambios locales SIN commit (no tocar sin autorización):
  - `android/app/src/main/kotlin/dev/nanoai/mobile/DebInstaller.kt`
  - `android/app/src/main/kotlin/dev/nanoai/mobile/channels/ChannelHandlers.kt`
  - `android/app/src/main/kotlin/dev/nanoai/mobile/channels/RuntimeChannelHandler.kt`
  - `lib/core/services/boot_orchestrator.dart`
  - `lib/core/services/nano_runtime_api.dart`
  - `lib/features/settings/presentation/screens/settings_screen.dart`
  - `lib/features/terminal/real_fs_shell.dart`
  - `lib/main.dart`
  - `api_full.patch` (untracked)
- `AGENTS.md` raíz: única regla es usar `graphify` (grafo en `graphify-out/`). Herramienta no disponible en entorno actual (`graphify_available: false`); no aplica hasta reinstalarla. No hay CLAUDE.md ni instrucciones adicionales en raíz ni en flutter_app.
- `lib/features/desktop/` está ignorado en `.gitignore:47` — cambios ahí no entran en commits (registrado en memoria de proyecto).

## 1. Arquitectura verificada

```
Usuario (tacto/voz futura)
  Flutter (Material 3, Riverpod, go_router)          lib/
    │ MethodChannel x6: runtime / exec_bin / pty /
    │   device_metrics / navigation / agent           lib/core/services/nano_runtime_api.dart
  Kotlin nativo                                        android/.../kotlin/dev/nanoai/mobile/
    │ AgentChannelHandler → AgentAccessibilityService (árbol accesible, gestos, launchPackage)
    │ ExecBinChannelHandler → DebInstaller / DownloadService / worker
    │ PtyChannelHandler → NanoshellBridge (JNI)
    │ NanoshellWorkerService (proceso :nanoshell, Messenger)
  C nativo (CMake, solo arm64-v8a)                     android/.../cpp/
    │ libnanoshell.so  — fork+dlopen de binarios PIE, spawn worker, PTY openpty manual
    │ libnanoroot.so   — LD_PRELOAD fakechroot (redirige rutas a NANO_ROOTFS)
  Linux/rootfs                                          files/nano/
    │ Termux bootstrap-aarch64.zip oficial + toybox/bash + proot
    │ Kali NetHunter minimal ARM64 (SHA256 verificado, vía proot)
    │ docker-compatible runtime propio (Registry API v2, proot, sin daemon)
    │ Escritorio: TigerVNC Xvnc + openbox + tint2 + feh + aterm (RFB 3.8 cliente Dart puro)
  Rust (products/nanoRUNTIME/)                         — HOY desconectado de la app
    │ nanortime-core  — ExecutionPlanner, PolicyEngine, OomGuard, Thermal, Battery, PromptCache, RateLimiter, hybrid router
    │ nanortime-ffi   — C ABI + JNI (compilada a libnanortime_ffi.so, sin consumidor)
    │ nanortime-cli   — servidor SSE POST /completion (compatible llama.cpp), /api/status, /api/chat
    │ nanortime-web   — servidor manual 8080, /api/chat, /api/status
  Motor LLM real hoy: llama-server (llama.cpp) adb-pusheado a /data/local/tmp/llama_libs/
    └─ sirve GET /health + POST /completion (SSE) — es lo único que el cliente Flutter consume
```

Ruta ejecutable actual de inferencia:
`ChatNotifier → LLMEngineClient (http://127.0.0.1:8080) → llama-server externo (adb)`.

Ruta objetivo:
`Flutter → RuntimeEngine (Dart) → EngineSupervisor (Kotlin) → nanortime-cli (Rust, PIE extraído) → nanortime-core → llama-cpp-2`.

## 2. Matriz declarado / implementado / conectado / probado

| Componente | Declarado | Implementado | Conectado | Probado | Evidencia |
|---|---|---|---|---|---|
| AccessibilityService | Sí | Sí | Sí | No (solo panel diagnóstico) | `AgentAccessibilityService.kt:33`; canal `AgentChannelHandler.kt:29`; UI `settings_screen.dart:189-299` |
| NanoRuntime FFI (JNI) | Sí | Sí (compilada) | **No** | No | `nanortime-ffi/src/jni_bridge.rs:126`; `.so` en jniLibs sin `System.loadLibrary` ni clase Kotlin; no trackeada en git |
| `/health` en motor | No (cliente lo exige) | **No** | — | — | `llm_engine_client.dart:27-42` pide `/health`; `nanortime-cli/src/server.rs` no lo tiene (grep `health` en nanoRUNTIME solo en cloud_provider) |
| `/completion` | Sí | Sí (Rust CLI) | Sí (pero contra llama-server, no Rust) | Sí (chat e2e) | `nanortime-cli/src/server.rs:115-194`; `chat_engine_test.dart:16-17` |
| NotificationListenerService | No | **Ausente** | — | — | 0 hits en android/ |
| RemoteInput | No | **Ausente** | — | — | 0 hits |
| TTS | No | **Ausente** | — | — | 0 hits `TextToSpeech` |
| STT | No | **Ausente** | — | — | 0 hits `SpeechRecognizer` |
| Keystore | No | **Ausente** | — | — | 0 hits; password VNC en SharedPreferences plano |
| Descarga GGUF | No | **Simulado** | No | No | catálogo con `downloaded` fijo; modelos por adb (`transfer_model.ps1`); `catalog_local_model_repository.dart` |
| Terminal PTY | Sí | Sí | Sí | Sí | `pty_shell.dart` → canal `com.nanoai/pty` → `pty_jni.c`; `pty_real_test.dart` |
| Escritorio VNC | Sí | Sí | Sí | Sí (manual + unit RFB) | `DesktopSessionManager.kt`, `vnc_client.dart`, `vnc_client_test.dart` |
| Kali vía proot | Sí | Sí | Sí | No e2e | `kali_manager.dart:24` (URL migrada 2026-08-13, SHA256 fijo) |
| Docker runtime | Sí | Sí | Parcial (CLI terminal) | No e2e | `docker_manager.dart:11-24` |
| Empaquetado Rust en APK | No | **No** | — | — | Gradle solo CMake C (`build.gradle.kts:39-44`); sin cargo |
| Permisos foreground/notificaciones | No (hoy) | — | — | — | Historia: existieron en `c546cf1`, `305a0d1`, `0a47186`; manifest actual sin ellos (grep 0 hits) |

## 3. Desalineamientos confirmados

1. **Motor real externo al producto**: APK instalada no puede inferir sin adb push previo (`llama-server` + `.gguf` en `/data/local/tmp`). Dependencia de desarrollo, no de producción.
2. **Rust huérfano en Android**: `libnanortime_ffi.so` (63.7 MB) en jniLibs sin consumidor y sin trackear en git. `nanortime-cli` sirve `/completion` pero no `/health`. `nanortime-web` no sirve ninguno de los dos. Cliente Flutter solo funciona contra llama-server.
3. **Build no reproducible para Rust**: ningún target de Gradle/CMake compila los crates; rutas cargo→aarch64 existen solo como comentarios (`jni_bridge.rs:4`) y scripts sueltos (`scripts/build_streaming_arm64.sh`).
4. **Estados simulados**: catálogo de modelos marca descargas inexistentes; no hay descarga reanudable ni verificación en la app.
5. **Accessibility limitada a diagnóstico**: API completa (dumpScreen/tap/swipe/inputText/globalAction/launchPackage) pero sin flujo de producto que la conecte al LLM.
6. **Sin capa de política de acciones**: el canal `com.nanoai/agent` expone acciones sin `ActionPolicyEngine` intermedio.
7. **Permisos históricos vs actuales**: FOREGROUND_SERVICE/POST_NOTIFICATIONS existieron en commits previos y fueron removidos; auditoría debe partir del manifest actual (solo INTERNET + medios).
8. **Seguridad local ausente**: sin Keystore, sin cifrado AES-GCM, password VNC en texto plano en SharedPreferences.

## 4. Clasificación de componentes

- **Activo**: terminal PTY, escritorio VNC, DebInstaller, rootfs/proot/Kali, docker runtime, chat (contra motor externo), dashboard métricas, agente accesibilidad (modo diagnóstico).
- **Parcial**: nanortime-cli (sin `/health` ni `/cancel`), modelo de datos GGUF (sin descarga real), AccessibilityService (sin flujo de producto).
- **Huérfano**: `libnanortime_ffi.so` (sin consumidor), `nanortime-web` (nadie lo consume), `real_fs_shell.dart` (solo desktop/tests, explícito `:26`).
- **Simulado**: `downloaded: true` en catálogo de modelos.
- **Duplicado**: dos servidores HTTP Rust (`nanortime-web` y modo server de `nanortime-cli`) con APIs distintas; dos bindings JNI de compatibilidad en `jni_bridge.rs:239-372`.
- **Inseguro**: password VNC plano; acciones de accesibilidad sin política; sin cifrado de preferencias sensibles.
- **No reproducible**: motor + modelos vía adb; `.so` no trackeada.

## 5. Riesgos

- **P0**: apk nueva sin inferencia (producto roto fuera del dev); acciones accesibilidad sin policy (riesgo seguridad/usuario); dependencia de ColorOS (execve bloqueado — por eso fork+dlopen, patrón obligatorio).
- **P1**: dos motores compitiendo (llama-server vs nanortime) si se empaqueta sin eliminar el otro; estado de motor representado por booleanos sueltos; sin cancelación de generación; zombis de procesos nativos.
- **P2**: deuda de documentación (informes con mezcla de commits); catálogo de modelos sin fuente de verdad remota; TalkBack loops si se agrega TTS sin cuidado.

## 6. ADR — Decisión del motor

### Alternativas

| | A: JNI/FFI | B: nanortime-cli proceso local (PIE+dlopen) | C: llama-server empaquetado | D: motor en rootfs |
|---|---|---|---|---|
| Reutiliza NanoRuntime | Sí | **Sí** | No | Sí |
| Streaming/cancelación | Manual (JNI complejo) | Ya existe (SSE `/completion`) | Ya existe | Ya existe |
| Build reproducible | Falta cargo→Gradle | Falta (mismo costo que A) | Compilar llama.cpp para ARM64 | No reproducible (rootfs descargado) |
| APK size | .so 63.7 MB ya compilada | Binario PIE ~similar | ~similar | 0 (descarga externa) |
| Arranque offline primera ejecución | Inmediato | Inmediato | Inmediato | **No** (necesita bootstrap) |
| Ciclo de vida Android | JNI en proceso app (riesgo OOM compartido) | Proceso supervisado (kill limpio) | Proceso supervisado | Proceso supervisado |
| Patrón existente en repo | No (sin consumidor) | **Sí** (nanoshell dlopen PIE + worker :nanoshell) | Parcial (solo adb hoy) | Sí (rootfs) |
| Compatibilidad OPPO/ColorOS | OK | OK (sin execve) | OK (sin execve) | OK |
| Migración cliente Flutter | Reescribir cliente | **Cero cambios** (contrato llama.cpp) | Cero | Cero |
| Riesgo | Alto (JNI+threading+ABI) | Bajo | Bajo | Medio |

### Decisión: **B — nanortime-cli como proceso local administrado**

Binario `nanortime` compilado cross aarch64 (staticlib llama-cpp-2 o enlace dinámico a libs ya en jniLibs), empaquetado como PIE en `assets/bin/`, extraído a `files/nano/`, arrancado con la infraestructura existente `nanoshell` (fork+dlopen, sin execve — compatible con las restricciones de ejecución de Android/ColorOS; no hay evasión de seguridad: dlopen de PIE desde el directorio de la app es un mecanismo soportado, todo bajo SELinux del proceso app).

Razones: reutiliza NanoRuntime completo (ExecutionPlanner/OomGuard), conserva contrato `/completion` que el cliente Flutter ya consume, ciclo de vida supervisable desde Kotlin, y el patrón de ejecución ya está probado en producción en este repo (terminal, worker, rootfs).

Consecuencias: `/health` + `/cancel` deben añadirse a `nanortime-cli` (trabajo menor en `server.rs`); se elimina la dependencia adb; `nanortime-web` se marca obsoleto (no se elimina aún); `libnanortime_ffi.so` huérfana se saca del APK (reducir ~64 MB) hasta que haya caso de uso JNI real.

Estrategia de migración: Fase B construye ruta B detrás de interfaz `RuntimeEngine`; llama-server adb sigue funcionando como motor de desarrollo hasta que B pase e2e en OPPO; después se retira.

Reversión: flag de build `NANOAI_ENGINE=llama_server_external` devuelve al modo adb; el cliente solo conoce `RuntimeEngine`.

## 7. Contrato único RuntimeEngine

```dart
abstract class RuntimeEngine {
  Future<void> start(EngineConfig config);   // modelo, ctx, gpu_layers, threads
  Future<void> stop();
  Future<EngineHealth> health();             // GET /health
  Future<EngineStatus> status();             // GET /api/status
  Future<void> loadModel(ModelSpec model);
  Future<void> unloadModel();
  Future<GeneratedText> generate(GenerateRequest r);       // POST /completion stream:false
  Stream<GenerateEvent> generateStream(GenerateRequest r); // SSE
  Future<void> cancel(String requestId);                   // POST /cancel
  Future<EngineMetrics> metrics();
  Future<void> dispose();
}
```

Estados (enum único, sin booleanos):

```
stopped → starting → ready → generating → ready | degraded | failed
                       ready → stopping → stopped
```

Endpoints mínimos del servidor: `GET /health`, `GET /api/status`, `POST /completion`, `POST /api/chat`, `POST /cancel`.
Contrato `/completion` (compat llama.cpp): body `{prompt, n_predict, temperature, top_p, stream, request_id}`; SSE `data: {token|content, stop, timings, request_id}`; error tipado `{error: {code, message, request_id}}`.

## 8. Fases y sprints

Regla transversal: una fase no avanza sin ruta funcional + evidencia (comando, salida, entorno). Cambios pequeños, verificables, reversibles. Sin commits sin autorización.

### Fase A — Evidencia y decisión (sin código nuevo)

| Sprint | Objetivo | Tareas | Done |
|---|---|---|---|
| A0 | Baseline reproducible | `flutter analyze` limpio en flutter_app; `assembleDebug` en clon limpio (patrón ya validado en `c546cf1`); correr tests unit Dart existentes; documentar salidas | Build + tests verdes en clon limpio, sin cambios locales del usuario |
| A1 | Matriz + ADR aprobados | Este documento como fuente de verdad; validar afirmaciones contra HEAD (no contra informes viejos) | Matriz §2 aceptada; ADR §6 aprobado |

### Fase B — Ruta oficial de inferencia

| Sprint | Objetivo | Archivos clave | Done |
|---|---|---|---|
| B1 | `/health` + `/cancel` + `request_id` en CLI Rust | `products/nanoRUNTIME/nanortime-cli/src/server.rs`, `main.rs`; tests Rust nuevos | `curl /health` responde `{status:"ok", model, version}`; cancel interrumpe generación; tests cargo verdes |
| B2 | Build cross aarch64 reproducible | Script versionado `scripts/build_nanortime_arm64.sh` (extiende `build_streaming_arm64.sh`); producto: `nanortime` PIE a `flutter_app/assets/bin/` | Build desde repo limpio genera binario; hash registrado; sin pasos manuales |
| B3 | `EngineSupervisor` Kotlin | Nuevo `EngineSupervisor.kt` + canal `com.nanoai/engine` en `MainActivity.kt`/`ChannelHandlers.kt`; spawn vía nanoshell dlopen (patrón `spawnGeneric`), health poll backoff limitado (máx N reintentos), kill limpio (grupo de procesos), registro PID, sin zombis, arranque fuera de main thread | Matar y relanzar motor 5x sin duplicados ni zombis (`ps` verificado) |
| B4 | `RuntimeEngine` Dart + migración Chat | Nuevo `lib/core/services/runtime_engine.dart`; `chatProvider` consume la interfaz (no `LLMEngineClient` directo); estados de motor en UI (dashboard chip) | Chat funciona contra nanortime-cli; estado `starting/generating/ready/degraded/failed` visible |
| B5 | Descarga GGUF real | Reescribir `catalog_local_model_repository.dart` + nuevo `model_downloader.dart`: estados `notInstalled→downloading→verifying→installed→loading→ready→failed`, SHA256 obligatorio, reanudable, `.part` + rename atómico, espacio previo, URLs HuggingFace reales; eliminar `downloaded: true` fijo | Instalar modelo 1.1B desde la app, verificación SHA256, borrado seguro |
| B6 | E2E sin adb | OPPO A79 Android 15: apk release instalada limpia, sin `/data/local/tmp/llama_libs` | Criterios MVP 1-4, 15-17 |

### Fase C — Explicar pantalla

| Sprint | Objetivo | Archivos clave | Done |
|---|---|---|---|
| C1 | Normalizador árbol accesible | Nuevo `lib/core/services/screen_explainer.dart` (o Kotlin): poda 800 nodos, dedup, extrae rol/texto/estado/acciones, límite tokens, excluye `isPassword`, ventanas `FLAG_SECURE` | Unit tests: árbol de prueba → payload ≤ X tokens sin campos sensibles |
| C2 | TTS Kotlin | Nuevo `TtsService.kt` + canal `com.nanoai/tts`: init/speak/stop/rate/pitch/isSpeaking/dispose; español; audio focus; stop al interactuar | Unit + instrumentado: habla y se detiene |
| C3 | Flujo "¿Qué hay en pantalla?" | Botón principal en Dashboard (o nueva pantalla principal); árbol → normalizar → `RuntimeEngine.generate` → TTS; acciones "siguiente botón"/"repetir" | Criterios MVP 5-7; prueba con app de prueba accesible |

### Fase D — Notificaciones y borradores

| Sprint | Objetivo | Archivos clave | Done |
|---|---|---|---|
| D1 | `NotificationListenerService` | Nuevo `NotificationListenerService` + permiso especial (activación manual) + `POST_NOTIFICATIONS` runtime + allowlist apps + dedup + filtro OTP/banca/persistentes | Notificación de prueba aparece en panel NanoAI; filtros verificados |
| D2 | Resumen + borrador local | Prompt local sobre notificación filtrada; borrador con destinatario/contenido; validación longitud; sin datos inventados; panel de borradores en UI | Borrador generado 100% local; borrador sin contexto pide aclaración |

### Fase E — Confirmación y respuesta

| Sprint | Objetivo | Archivos clave | Done |
|---|---|---|---|
| E1 | `ActionPolicyEngine` Kotlin | Nuevo `ActionPolicyEngine.kt`: `sealed interface AgentAction` (ExplainScreen/FocusNode/ClickNode/InputText/Scroll/DraftReply/SendNotificationReply/Speak/LaunchApprovedApp); niveles 0-3; cada acción con id/fuente/riesgo/expiración/confirmación/evidencia/timestamp; bloqueados: pagos, OTP, contraseñas, seguridad | Unit tests niveles y bloqueos |
| E2 | Confirmación | UI grande accesible: destinatario + contenido + expiración; idempotencia (id de borrador); anti doble envío | Segundo intento no duplica (test instrumentado) |
| E3 | `RemoteInput` | Enviar solo si la notificación original sigue activa y ofrece RemoteInput; verificación identidad app/conversación; PendingIntent; log de éxito técnico real (no "enviado" si solo hubo entrega del intent); sin RemoteInput: mantener borrador + abrir app, sin sustitución silenciosa por Accessibility | Criterios MVP 11-13 |

### Fase F — Seguridad

| Sprint | Objetivo | Archivos clave | Done |
|---|---|---|---|
| F1 | Keystore + AES-GCM | Nuevo `CryptoStore.kt` (AndroidKeyStore); cifrar password VNC y preferencias sensibles; migración desde plano | Datos sensibles cifrados; verificado con instrumentado |
| F2 | Retención y privacidad | Eliminación de historial (chat/notificaciones); redacción PII antes de routing cloud; logs sin contenido sensible; token de sesión para acciones sensibles del servidor local | Revisión de logs limpia; borrado verificado |

### Fase G — Linux Tool Gateway

| Sprint | Objetivo | Archivos clave | Done |
|---|---|---|---|
| G1 | Catálogo de herramientas tipadas | Nuevo `lib/core/services/linux_tool_gateway.dart`: `listApprovedTools/executeApprovedTool/cancel/status/logs`; cada tool: id fijo, ejecutable permitido (allowlist existente), esquema JSON de argumentos, timeout, dir de trabajo, límite de salida, nivel de riesgo, auditoría | Ejecutar tool aprobada con argumentos validados; argumento inválido rechazado con error tipado |
| G2 | Integración rootfs | Tools sobre `execRootfs`/worker existentes; sin `bash -c <texto libre>` desde el LLM | Tool real (ej. `network_diagnostic`) ejecutada desde el agente con evidencia |

### Fuera de alcance MVP (posteriores)

STT (interfaz definida, impl con `SpeechRecognizer` on-device o whisper.cpp), cámara/OCR, alarmas/Maps, automatizaciones generales, soporte NPU, cuantización runtime.

## 9. Criterios de aceptación del MVP (20)

1. APK se instala sin adb push del motor.
2. Usuario instala o selecciona modelo desde la app.
3. Motor tiene health check real.
4. App distingue motor iniciado / modelo cargado / generación activa.
5. "Explicar pantalla" funciona sobre app de prueba accesible.
6. Campos sensibles no entran al prompt.
7. TTS lee el resumen y se puede detener.
8. Notificación de prueba aparece en NanoAI.
9. NanoAI genera borrador local.
10. Usuario escucha/lee destinatario y contenido.
11. Mensaje solo se responde tras confirmar.
12. Segundo intento no duplica el envío.
13. Sin RemoteInput: no se simula envío exitoso.
14. TalkBack y NanoAI sin loops de foco ni doble lectura grave.
15. Motor se detiene limpiamente.
16. No quedan procesos zombis.
17. App funciona offline.
18. Terminal, rootfs y escritorio existentes no se rompen.
19. Tests relevantes pasan.
20. Informe final distingue probado / parcial / pendiente.

## 10. Mapa final

```
Usuario
  Flutter (modos Access/Assistant/Pro)
  AgentController (Dart)
  Kotlin Android Services (accessibility, notificaciones, TTS, engine supervisor)
  ActionPolicyEngine (determinista, niveles 0-3)
  RuntimeEngine (contrato único)
  NanoRuntime (Rust: ExecutionPlanner, PolicyEngine, OomGuard, thermal, battery)
  Backend de inferencia (llama-cpp-2, GGUF local)
  Android Tool Gateway (notificaciones, accesibilidad, TTS)
  Linux Tool Gateway (rootfs/proot/Kali/docker, herramientas aprobadas)
```

## 11. Guardas permanentes

- El LLM nunca ejecuta shell arbitrario, ni accede directo a Accessibility, ni envía mensajes por decisión propia.
- Sin ADB en producción (solo dev/diagnóstico).
- Sin dos motores simultáneos sin justificación.
- Sin permisos "por si acaso" — cada permiso documentado: función, momento, denegación, revocación, retención.
- Sin métricas ni descargas simuladas.
- Sin commits/push/PR sin autorización expresa.
- Mecanismo de ejecución nativa: fork+dlopen de PIE dentro del sandbox del proceso app (compatible con restricciones Android/ColorOS), no "evasión de SELinux".
- `isAccessibilityTool="true"` solo si se cumple el propósito declarado y requisitos aplicables.

## 12. Próximo paso autorizado

Fase A (A0: baseline build+tests en clon limpio; A1: aprobación de este ADR) y luego Fase B. No escribir código de producto hasta aprobar este plan.
