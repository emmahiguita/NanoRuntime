# 01 — RUNTIME CALL GRAPH (flujo real hoy)

Reconstruido del código (no del diseño). Todas las referencias son archivo:línea relativas a `nanoMOBILE/flutter_app/`.

## A. Automatización WhatsApp (notificación entrante → envío)

```
notificación Android
 └─ NotificationListenerService (Kotlin) → EventChannel
    └─ lib/features/automation/engine/scheduling/notification_event_router.dart
       ├─ decode → dedupe → burst_gate → burst-shadow (persistencia de eventos)
       ├─ _canAdmitThermally()  notification_event_router_thermal.part.dart:8
       │    status >= 4 → defer (antes >=3; cambiado 2026-10-16 por falso positivo ColorOS)
       └─ rule_dispatcher.dart
          ├─ reglas → verdict proceed
          └─ conversation_reply_composer.dart (composeSuggestions / _composeConversation)
             └─ conversation_reply_flow.dart
                ├─ businessFacts (canal comercial)
                ├─ _personalEarlyReply (determinista, sin LLM)
                ├─ thermal gate línea 145: >=4 suprime; SEVERE degrada
                └─ _draftSource → RuntimeNotificationDraftWriter
                   └─ notification_draft_writer_generation.part.dart:6 _generateDraftReply
                      ├─ cloud port (si configurado)  → proveedor API
                      ├─ localReady → _ensureReady(writer._modelPath())
                      ├─ ExecutionBudget (180 s por defecto)
                      └─ generateWithColdRetry → writer._client.generate/... 
                         = RoutedLlmEngineClient (lib/core/services/routed_llm_engine_client.dart)
                            ├─ useLiteRt() → LiteRtInferenceAdapter.generateTokens
                            │    → MethodChannel com.nanoai/litert → LiteRtChannelHandler.kt
                            │       → NanoModelRuntimeSupervisor.ensureReady/generate
                            │          → LocalModelGate.mutex (single-flight)
                            │          → InferenceThermalGuard.checkAdmission/protect
                            │          → LiteRtEngineOwner.initialize (Engine + Conversation)
                            │          → LiteRtGeneration.generate (reuso de Conversation si history+session idénticos)
                            ├─ useMnn() → MnnInferenceAdapter → com.nanoai/mnn → MnnChannelHandler
                            │       → MnnRuntimeSupervisor → MnnNative.kt → mnn_jni.cpp
                            │          (mensajes estructurados → jinja nativo → prefill delta/KV reuse)
                            └─ else → llama.cpp HTTP (GGUF) via LlamaEngineClient
                      ├─ calidad: ConversationReplyQuality.rejectionReason
                      │    (echo / repeated_characters / repeated_words / empty)
                      ├─ regeneración única por estilo (_qualityRevisionInstruction)
                      └─ retorno del borrador
                   └─ flujo: guardas finales → [draft] output rejected | aceptado
└─ envío: rule_dispatcher.dart:586 'draftsSent' tras replyVerified/replyDispatchedUnverified
   └─ persistencia outbound → canonical_messages (Kotlin CanonicalMessageSqlStore.kt /
      CanonicalConversationMirror.kt / WebHistoryStoreHandler.kt)
```

Puntos de decisión con estado:
- `notification_draft_writer_draft.part.dart:70` `includePersonaInPrompt: hasCloudPort` — decide rama de prompt.
- `notification_draft_writer_prompt.part.dart:125-186` — modo `pure`/`localConversation`/`personalReply`/estándar; `compactSystem` para paquetes de KV pequeño; `_personaForCapacity` (cap 280 chars solo ekv1280).
- `notification_draft_writer_capacity.part.dart:7` `_needsCompactPersonalSystem` = MNN o `qwen3_0.6b...ekv1280.litertlm`.

## B. Chat manual

```
UI chat → ChatSendUseCase.execute (lib/features/chat/application/chat_send_use_case.dart:106)
 ├─ ChatTurnRouter.tryRoute (herramientas locales/comandos) :133
 ├─ apiProviderSelected → ChatApiTurnHandler (cloud) :162-174
 ├─ sin modelo → ChatWebAiFallback :176-183
 └─ motor local:
    ├─ engine.ensureReady(modelPath: activeModelPath) :186 (RuntimeEngineNotifier)
    └─ ChatInferenceCoordinator.generateRound :249
       ├─ ChatContextBuilder (prompt/historial manual)
       ├─ engine.client.generateStream (mismo RoutedLlmEngineClient)
       ├─ temperature/topP/maxTokens desde settingsProvider (settings.temperature :256)
       └─ streaming → listener.onStreamingText → UI; onInferenceSuccess → persistencia chat
```

Diferencia clave vs automatización: el chat manual NO pasa por `ConversationReplyQuality` (no hay guarda antieco en chat manual). HYPOTHESIS: ecos vistos por el usuario en chat manual no serían bloqueados por ninguna guarda — pendiente de verificación (test manual).

## C. Headless/background

- `MainActivity.kt` y `AutomationRuntimeChannels.kt` registran los mismos MethodChannels para el service sin pantalla; ambos comparten `NanoModelRuntimeSupervisor`/`MnnRuntimeSupervisor` (object singleton en proceso).
- El motor headless relee datos personales antes del prompt (regla del skill nano-real-chat-validation).

## D. Hilos/isolates

- Flutter main isolate: orquestación, router, calidad, persistencia.
- Kotlin: `Dispatchers.IO` para initialize/generate (`LiteRtChannelHandler.kt:60-90`); callbacks de token posteados a main handler.
- JNI MNN: hilo de la llamada Kotlin (IO), con `std::mutex modelMutex` en `mnn_jni.cpp`.
- LiteRT-LM: pool nativo C++ interno del engine; callbacks acoplados a JVM (internos de la lib, no de Nano).
- GGUF: proceso separado (worker/nanoshell), HTTP.
