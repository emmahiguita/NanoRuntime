# 05 — CONCURRENCY AUDIT

## Mapa de hilos y dueños

| Hilo | Dueño | Qué hace |
|---|---|---|
| Main isolate (Flutter) | Router/draft writer | Orquesta; NUNCA bloquea en inferencia (invokeMethod async) |
| Dispatchers.IO (Kotlin) | `LiteRtChannelHandler.kt:60-90` | initialize + generate LiteRT |
| Dispatchers.IO (Kotlin) | `MnnChannelHandler.kt:37-46` | generate MNN |
| Hilo C++ pool | LiteRT-LM interno | prefill/decode; callbacks JNI |
| Hilo de llamada JNI (IO) | `mnn_jni.cpp` | prefill/decode MNN bajo `std::mutex modelMutex` |
| Proceso separado | `NanoshellWorkerService` | servidor GGUF/whisper HTTP |

## Garantías encontradas (positivas)

1. **Single-flight**: `LocalModelGate.mutex` serializa ensureReady/generate/close para LiteRT (`NanoModelRuntimeSupervisor.kt:46,91`) y MNN (`MnnRuntimeSupervisor.kt:71`). Un solo requestId admitido a la vez por motor (mapa `requests`).
2. **Cancelación por requestId**, no por modelo: `NanoModelRuntimeSupervisor.cancelInference` / `MnnRuntimeSupervisor.cancel` recorren `requests`; el cancel de un chat no mata el otro.
3. **Cancelar mata la conversación**: `LiteRtGeneration.generate` cierra `Conversation` en `finally` cuando el turno no completó (sesión envenenada no se reutiliza). Verificado en el código Kotlin.
4. **Unload espera decode**: `mnn_jni.cpp` unload toma `modelMutex` (espera a que termine la generación). MNN seguro frente a use-after-free.
5. **Callbacks posteados a main handler** (`MnnChannelHandler.kt:40`, `LiteRtChannelHandler`): sin corrupción de estado Flutter desde hilos nativos.
6. **Cerrado de stream cierra el receptor antes de admitir otro** (`litert_stream_lifecycle.dart:29-35`).

## Riesgos (con severidad)

1. **P2 — Dos chats sobre el mismo engine comparten Conversation física**: `LiteRtGeneration` reusa Conversation solo si `session` coincide; sesiones distintas crean Conversation nueva, pero el ENGINE es uno y `NanoModelRuntimeSupervisor.generate` ya está serializado por el mutex — OK por single-flight, PERO un segundo turno concurrente espera en el mutex (cola, no rechazo). El presupuesto de espera del draft (180 s) puede agotarse en cola. Medir cola vs. trabajo.
2. **P2 — Thermal guard monitor cada 5 s en `protect()`**: en SEVERE con modelo pesado cancela el decode activo. Correcto por diseño; documentado.
3. **P3 — Warm-unload 90 s vs. turnos consecutivos**: `scheduleWarmUnload` descarga el engine a los 90 s idle (0 en CRITICAL, 15 s en SEVERE para livianos). Entre ráfagas de notificaciones puede recargar (3.5 s CPU — tolerable). No es carrera, es latencia.
4. **HYPOTHESIS — Doble generación en chat manual**: `ChatStreamSession.isGenerationCurrent` guarda contra turnos viejos (`chat_send_use_case.dart:144,187`), pero si dos widgets escuchan el mismo stream se duplicarían callbacks de UI. Pendiente de test UI.

## Veredicto

No se encontró acceso concurrente a la misma sesión. Single-flight efectivo en los tres motores. Las colas existen implícitamente en el mutex; no hay generación doble demostrada.
