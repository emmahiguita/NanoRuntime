# 08 — CONVERSATION AUDIT (roles, persona, historial, template, KV)

## Roles

- Canal nativo LiteRT: `LiteRtGeneration.generate` construye `Message.user`/`Message.model` + `systemInstruction` — roles correctos, plantilla del .litertlm.
- Canal MNN: mensajes estructurados role/content desde Dart → JNI construye `ChatMessages` → jinja nativa (`mnn_jni.cpp`, plantilla inyectada en `set_config`). Roles conservados hasta el nativo. FIX 2026-10-16.
- Chat manual: `ChatContextBuilder` (verificar si pasa `history` estructurado al `generateStream` — el cliente sí lo acepta como `List<Map<String,String>>`). HYPOTHESIS: sí estructurado; pendiente verificación línea exacta.
- Confusión USER/ASSISTANT observada históricamente ("Yo soy hombre 😍"): NO reproducida en esta sesión. La normalización de historial distingue `inbound→user` / `outbound→assistant` (`notification_draft_writer_personal_prompt.part.dart:111-115`, `canonical_prompt_memory.dart:107-114`). HYPOTHESIS: la causa anterior fue el prefill completo MNN con ChatML manual + modelo 3B degradado por contexto; sin reproducción, queda abierta con test.

## Persona

- **Evidencia de persona vacía**: `[draft:prepared] personaChars=0` en turnos de contacto nuevo (14:46 "Como estas"). `[personal-retriever] candidates=0 eligible=0`.
- `_personalTurnPrompt` con persona vacía devuelve SOLO el mensaje (`personal_prompt.part.dart:38-39`) → el 0.6B sin anclaje produce eco (medido).
- Invariante pedido ("persona != empty o NO GENERATE") NO está implementado. Hay fallback de sistema (`_nativePersonalSystem`) pero sin persona como dato.
- Recomendación: persona base explícita por defecto (estilo, no hechos) cuando `candidates=0`, o pasar el turno al modo identidad. P1.

## Historial

- Ventana nativa: 12 mensajes / 6 K chars (`personal_prompt.part.dart:95-118`); ventana diagnóstica 4.
- Fuente canónica única: `canonical_messages` (`CanonicalMessageSqlStore.kt`, lectura `ConversationSqlMessageReader.kt`).
- Orden verificado: genera → valida (`ConversationReplyQuality` + guards) → solo aceptado persiste/envía (`rule_dispatcher.dart:586` marca `draftsSent` tras `replyVerified`/`replyDispatchedUnverified`; el flujo rechaza antes: `[draft] output rejected: quality=echo` sin envío). **No se encontró persistencia de candidato crudo antes de validar**.
- Regeneración por calidad: una sola, acotada, con las mismas guardas (`notification_draft_writer_generation.part.dart:135-162`); el borrador rechazado NO se inyecta al historial.

## Template

- LiteRT: template dentro del .litertlm (minja) — Nano no formatea. ✓
- MNN: paquete Omni sin `jinja` en config.json (verificado) → Nano inyecta la plantilla Qwen2.5/Omni oficial vía `set_config`. Antes: ChatML manual en Dart (corregido).
- GGUF: `ChatTemplate` del catálogo formateado en Dart para el servidor HTTP (revisar `formatConversationHistory`) — única ruta con template en Dart; aceptable para el servidor llama.cpp que recibe texto, pero debe quedar documentada.

## KV / contexto

- LiteRT: presupuesto por paquete (`LiteRtContextBudget.kt`, qwen3 ekv1280: 1280 tokens, reserva 32, estimador byte-BPE 0.6 tras fix); descarta turnos viejos (historyDropped) antes de exceder.
- MNN: `max_all_tokens` 2048 default; JNI clamp de maxTokens + `CONTEXT_CAPACITY_EXCEEDED` si el prompt completo no cabe; cache de prompt invalidada en cancel/divergencia (full prefill seguro).
- Context shifting/summarization: NO implementado (el budget descarta turnos viejos, suficiente para KV 1280/2048 por ahora).
