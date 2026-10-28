# 00 — PROJECT MAP (Nano Mobile)

Auditoría forense. Fecha: 2026-10-16. Dispositivo: CPH2557 (OPPO A78 5G), MT6833 (Dimensity 700), 8 GB RAM, Android (ColorOS).

Convenciones: estado = ACTIVO / LEGACY / DEAD / UNKNOWN. Referencias relativas a `nanoMOBILE/flutter_app/`.

## Capas

| Capa | Directorio | Runtime relacionado |
|---|---|---|
| UI/estado (Flutter) | `lib/features/**`, `lib/core/providers/**` | — |
| Servicios core | `lib/core/services/**` | LiteRT, MNN, GGUF |
| Puente Kotlin (MethodChannel/EventChannel) | `android/app/src/main/kotlin/dev/nanoai/mobile/**` | LiteRT, MNN, GGUF |
| JNI C++ | `android/app/src/main/cpp/mnn_jni.cpp` | MNN |
| Servidor nativo (llama.cpp/whisper.cpp, proceso separado) | `EngineSupervisor.kt` + nanoshell/worker | GGUF, Whisper |
| Persistencia | SQLite (`AutomationStoreDb`, `canonical_messages`), SharedPreferences | — |

## Motores de inferencia encontrados

| Motor | Archivos núcleo | Estado |
|---|---|---|
| LiteRT-LM (.litertlm) | `lib/core/services/litert_inference_adapter.dart`, `litert_stream_lifecycle.dart`, `android/.../channels/LiteRtEngineOwner.kt`, `LiteRtGeneration.kt`, `LiteRtChannelHandler.kt`, `LiteRtContextBudget.kt`, `runtime/NanoModelRuntimeSupervisor.kt` | ACTIVO (principal de automatización desde 2026-10-16) |
| MNN (.mnn, paquete Omni) | `lib/core/services/mnn_inference_adapter.dart`, `mnn_stream_lifecycle.dart`, `android/.../mnn/MnnNative.kt`, `runtime/MnnRuntimeSupervisor.kt`, `channels/MnnChannelHandler.kt`, `cpp/mnn_jni.cpp`, CMake MNN 3.6.1 | PARCIAL (opción de chat; automatización lo usaba antes) |
| llama.cpp GGUF (servidor "nanortime" HTTP) | `lib/core/services/runtime_gguf_lifecycle.dart`, `llm_engine_client.dart`, `nano_runtime_api.dart`, `EngineSupervisor.kt`, `NanoshellWorkerService.kt`, `engine_watchdog_coordinator.dart` | LEGACY/UNKNOWN para chat; ACTIVO para Whisper STT (`whisper_stt_service.dart` importa `nano_runtime_api.dart`) |
| Whisper.cpp (STT) | `lib/core/services/whisper_stt_service.dart`, `ggml-tiny.bin` | ACTIVO vía nanortime |
| ML Kit / clasificadores | `android/.../channels/LanguageAssistChannelHandler.kt` (sugerencias/clasificación) | ACTIVO (no es LLM) |

## Rutas de conversación

1. **Automatización WhatsApp (notificaciones)**: `notification_event_router.dart` (decode → dedupe → burst) → `rule_dispatcher.dart` → `conversation_reply_composer.dart` → `conversation_reply_flow.dart` → `RuntimeNotificationDraftWriter` (`notification_draft_writer*.part.dart`) → `RoutedLlmEngineClient` → motor. Quality: `conversation_reply_quality.dart` + `conversation_decision_guards.dart`. Persistencia: `canonical_messages` (Kotlin `CanonicalMessageSqlStore.kt`, `CanonicalConversationMirror.kt`).
2. **Chat manual**: `chat_send_use_case.dart` → `ChatTurnRouter` (determinista) → API cloud (`ChatApiTurnHandler`) → WebAI fallback → `ChatInferenceCoordinator.generateRound` → `engine.client` (mismo `RoutedLlmEngineClient`). Prompt: `chat_context_builder.dart` (`ChatContextBuilder`), `chat_system_prompt.dart`.
3. **Background/headless**: `NanoshellWorkerService.kt` + headless engine (`MainActivity` registra canales para service sin pantalla); comparte supervisores (`NanoModelRuntimeSupervisor`, `MnnRuntimeSupervisor`).

## Selección de motor

`lib/core/models/catalog_models.dart:113` `NeuralCatalog.backendForPath()` decide por nombre de archivo → `ModelBackendType {gguf, litertlm, mnn}` (no por extensión). `routed_llm_engine_client.dart:46-48` consulta `useLiteRt()/useMnn()` por llamada. `runtime_engine.dart` (`RuntimeEngineNotifier`) serializa arranque/parada; `runtime_local_lifecycle.dart:78-94` arranca LiteRT o MNN y libera el otro.

## Catálogo (20 entradas, resumen por backend)

- litertlm (14): Qwen3-0.6B (KV 1280), LFM2.5-230M, Qwen2.5-1.5B (ekv4096, q8, 1.49 GB), Gemma-4-E2B (2.6 GB), DeepSeek-R1-Distill-Qwen-1.5B, Qwen3-4B, etc.
- mnn (1): Qwen2.5-Omni-3B (perfil texto `llm_config.json`; visual/audio/talker en disco pero sin cargar).
- gguf (resto): Qwen2.5-1.5B-Instruct Q4_K_M, Qwen2.5-3B, etc.

## Archivos clave por dominio

| Dominio | Archivo |
|---|---|
| Supervisión LiteRT | `runtime/NanoModelRuntimeSupervisor.kt` |
| Supervisión MNN | `runtime/MnnRuntimeSupervisor.kt` |
| Barrera global de motor | `LocalModelGate` (mismo paquete `runtime/`) |
| Guarda térmica | `runtime/InferenceThermalGuard.kt` + `performance/NanoThermalMonitor.kt` + gates Dart (`notification_event_router_thermal.part.dart`, `conversation_reply_flow.dart:145`) |
| Budget contexto LiteRT | `channels/LiteRtContextBudget.kt` |
| Calidad/respuesta | `lib/core/services/conversation_reply_quality.dart`, `lib/features/automation/personal_agent/application/conversation_decision_guards.dart` |
| Persona | `agent_dependencies.dart:personaContextProvider`, `notification_draft_writer_personal_prompt.part.dart` |
| Historial canónico | `automation/CanonicalMessageSqlStore.kt`, `ConversationSqlMessageReader.kt`, `lib/.../engine/messaging/canonical_context_builder.dart` |
| TTFT/tok-s | `LiteRtChannelHandler.kt` (métricas `LiteRtGeneration`), `mnn_jni.cpp` (`prefill_ms`, `ttft_ms`, `decode_tok_s`) |

## Modelos en dispositivo (evidencia `run-as dev.nanoai.mobile ls files/nano/models`)

- `Qwen2.5-Omni-3B-MNN/` (llm.mnn.weight 1.7 GB)
- `qwen3_0.6b_nothink_q4_block32_ekv1280.litertlm` (347 MB)
- `LFM2.5-230M_int8.litertlm` (266 MB)
- `gemma-4-E2B-it.litertlm` (2.6 GB, NUNCA cargado — UNVERIFIED)
- `Qwen2.5-1.5B-Instruct-Q4_K_M.gguf` (GGUF)
- `ggml-tiny.bin` (Whisper)

## Sospechas de duplicación (detalle en 04)

- Política térmica en dos lugares (Dart gates + `InferenceThermalGuard`) — solapada pero no idéntica (Dart admite, Kotlin decide por peso).
- Selección GPU/CPU duplicada: `runtime_local_lifecycle.dart:82-95` y fallback Kotlin en `NanoModelRuntimeSupervisor.ensureReady` (cinturón+tirantes, deliberado tras mediciones).
- Varios "coordinator" (`ChatInferenceCoordinator`, `nano_inference_coordinator.dart`, `AutomationCoordinator`, `InferenceResourceCoordinator` no existe) — capas, no duplicados funcionales; ver 04.
