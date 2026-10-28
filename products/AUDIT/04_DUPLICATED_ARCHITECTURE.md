# 04 — DUPLICATED ARCHITECTURE

Hallazgos de solapamiento real (con archivo:línea). No se fusiona nada durante la auditoría.

## Duplicados reales

1. **Política térmica en dos capas** (P2)
   - Dart: `notification_event_router_thermal.part.dart:11`, `conversation_reply_flow.dart:145`, `conversation_reply_composer.dart:128`.
   - Kotlin: `InferenceThermalGuard.kt` (`checkAdmission`/`protect`), más `NanoThermalMonitor.kt` (listener + thread scale).
   - Solapamiento intencional pero con responsabilidades distintas hoy: Dart admite el turno, Kotlin decide por peso del modelo. Riesgo de divergencia futura: consolidar criterio en UN solo lugar (recomendado: Kotlin como autoridad, Dart solo consulta).
2. **Selección GPU/CPU duplicada** (P2)
   - `runtime_local_lifecycle.dart:82-95`: `_initializeLiteRt` intenta GPU y cae a CPU (por disponibilidad OpenCL + tamaño de modelo).
   - `NanoModelRuntimeSupervisor.ensureReady` (Kotlin): reintenta CPU si `initialize(gpu)` lanza.
   - Cinturón+tirantes tras mediciones de Mali (Mali-G57 OpenCL: 0.8–5.4 tok/s vs CPU 15.1 tok/s). Consolidar en Kotlin; Dart debe solo pasar preferencia.
3. **Dos supervisores de motor nativo** (P2, justificado por backends distintos)
   - `NanoModelRuntimeSupervisor` (LiteRT) y `MnnRuntimeSupervisor` (MNN) comparten patrón (leases por cliente, mutex `LocalModelGate`, thermal guard) pero no código. Si MNN se degrada a opción de chat, extraer una interfaz común `NativeEngineSupervisor`.
4. **Coordinadores "coordinator"** (P3 — son capas, no duplicados)
   - `ChatInferenceCoordinator` (chat manual), `nano_inference_coordinator.dart` (coordina motor + watchdog + colas), `AutomationCoordinator` (automatización), `EngineWatchdogCoordinator` (GGUF). Se tocan en orden; no hay dos dueños del mismo estado.
5. **Prompt/historial manual del chat** (P1, riesgo)
   - `ChatContextBuilder` + `chat_system_prompt.dart` construyen el prompt del chat manual EN DART, distinto del camino del draft writer. Dos constructores de contexto que deben mantenerse coherentes (persona, policy, historial). Verificar si el chat manual reutiliza `formatConversationHistory` o duplica la lógica — HYPOTHESIS: parcialmente duplicado.

## Código obsoleto / residual

- `runtime_gguf_lifecycle.dart` + `EngineSupervisor.kt`: sin actividad en capturas recientes (UNKNOWN, no DEAD: Whisper STT depende de `nano_runtime_api.dart`).
- Import de `mnn_inference_adapter.dart` en `routed_llm_engine_client.dart:8` — activo (ruta MNN viva).
- `docker_manager.dart`, `proot_manager.dart`, `rootfs_manager.dart`, `kali_manager.dart`: infraestructura de sandbox para el servidor GGUF/terminal; no son inferencia per se. UNKNOWN si el chat los usa.

## Conclusión de duplicación

No hay DOS ConversationCore. No hay dos rutas de persistencia canónica (canonical_messages es única; el fallback `conversation_messages` en `ConversationSqlMessageReader.kt:57` es lectura legacy). La duplicación principal es térmica y backend-selection — acotada y corregible.
