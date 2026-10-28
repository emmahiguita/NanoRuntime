# 09 — BUGS

Leyenda: FIXED = corregido y construido esta sesión; OPEN = pendiente; HYPOTHESIS = sin confirmación.

| ID | Sev | Archivo:Método | Causa | Evidencia | Corrección | Estado |
|---|---|---|---|---|---|---|
| B1 | P0 | `InferenceThermalGuard.kt:checkAdmission` + gates Dart (`conversation_reply_flow.dart:145`) | ColorOS marca SEVERE permanente con piel 45 °C (sensor `shell_skin` mStatus=3; CPU 62 °C status 0) → TODA inferencia bloqueada | `dumpsys thermalservice` (shell_skin 45.0 mStatus=3), log `[conversation-compose] thermal 3: suprimido`, `deferred_before_admission status=3` | SEVERE degrada (solo modelos livianos), CRITICAL+ bloquea; gates Dart `>=4` | FIXED |
| B2 | P1 | `mnn_jni.cpp` (generate) | `reset()` + `response(prompt)` por turno = prefill COMPLETO del historial cada mensaje | Comentarios repo: 44.8 s prefill, 111 s TTFT (CPH2557) | reuse_kv + prefill delta + prompt-cache JNI + invalidación segura | FIXED |
| B3 | P1 | `mnn_stream_lifecycle.dart:_chatMl` | ChatML ensamblado a mano en Dart (template del modelo ignorado) | Código previo; paquete Omni sin jinja en config.json (verificado en dispositivo) | Mensajes estructurados role/content hasta JNI; jinja Qwen2.5/Omni inyectada en `set_config`; render nativo | FIXED |
| B4 | P1 | `LiteRtContextBudget.kt:27-36` | Cota en BYTES UTF-8 como proxy de tokens → rechazaba prompts válidos en KV 1280 | Log `CONTEXT_CAPACITY_EXCEEDED: entrada obligatoria no cabe en Qwen3` con promptChars=945 | Estimador de tokens byte-BPE (0.6/byte, cota alta documentada) | FIXED |
| B5 | P1 | `NanoModelRuntimeSupervisor.ensureReady` | GPU fallaba → estado FAILED permanente, sin fallback | Diseño previo; Mali frágil | Reintento CPU automático en Kotlin (+ fallback Dart existente) | FIXED |
| B6 | P1 | Selección de backend `runtime_local_lifecycle.dart:82` | Mali-G57 OpenCL lento para modelo memory-bound: 0.8–5.4 tok/s vs CPU 15.1 tok/s | Métricas logcat mismo modelo en ambos backends | Política: litertlm <1 GB → CPU XNNPACK; ≥1 GB → GPU | FIXED |
| B7 | P1 | `notification_draft_writer_personal_prompt.part.dart:31` + persona provider | persona vacía (contacto nuevo) → prompt = mensaje pelado → 0.6B hace eco/degenera | Logs `personaChars=0`, `cause=echo`, `cause=repeated_characters` (128 tokens) | Invariante persona-no-vacía (persona base por defecto) o no generar; candidato: modelo 1.5B para automatización | OPEN |
| B8 | P2 | `notification_draft_writer_prompt.part.dart:116` | KV 1280 no cabe persona completa + contrato | B4/B7 | Sistema compacto para paquetes de KV mínimo + cap persona 280 chars solo ekv1280 | FIXED |
| B9 | P2 | Flujo draft | Rechazo de calidad → regeneración completa (+4–13 s) y luego fallback web (~5 s) → silencio final | `[draft:quality] cause=echo retry=1` + `web result rejected` + `no reply` | Aceptable como guarda; el arreglo real es B7 (modelo coherente). No debilitar guardas | OPEN (depende de B7) |
| B10 | P3 | `conversation_reply_flow.dart:145` vs Kotlin | Umbral térmico divergente entre capas | Tras B1, Dart `>=4`, Kotlin por peso | Consolidar en Kotlin como autoridad | OPEN |
| B11 | P3 | Warm-idle 90 s | Turnos espaciados >90 s pagan cold start (3.5–13.9 s) | Logs `ensure loaded=false` tras idle | warm-idle por actividad de conversación, no solo tiempo | OPEN |
| B12 | P3 | Gemma 4 E2B | 2.6 GB en 8 GB RAM (1.9 GB libres) → OOM probable | Sin intento registrado | Probar con medición; no ofrecer en este dispositivo si OOM | UNVERIFIED |
| B13 | HYPOTHESIS | Chat manual | Sin QualityGate (ConversationReplyQuality solo en draft writer) → ecos en chat manual no bloqueados | `chat_send_use_case.dart` no importa el quality service | Verificar en chat manual; si ocurre, reutilizar el mismo gate | OPEN |

Notas:
- B2/B3/B4/B5/B6/B8 fueron corregidos EN ESTA sesión y están construidos e instalados (builds 14:14, 14:52). Las mediciones post-fix (CPU 3.5 s carga, 15.1 tok/s) confirman la parte de rendimiento.
- Ningún hallazgo se ocultó con try/catch; los rechazos siguen visibles en logs (`[draft] output rejected`).
