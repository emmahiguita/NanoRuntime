# REMEDIATION PLAN

Orden por severidad. Cada cambio incluye: problema, causa raíz, archivos, solución, riesgo, criterio de aceptación.

## P1-1. Modelo de automatización coherente (cierra B7/B9)

- Problema: eco/repeated_chars del 0.6B con persona vacía; cada rechazo cuesta otra generación y termina en silencio.
- Causa raíz: modelo 0.6B q4 insuficiente para redacción personal; persona vacía en contactos nuevos.
- Archivos: ninguno (cambio de datos/operación). `files/nano/models/` + prefs `automationModelPath`.
- Solución:
  1. Colocar `Qwen2.5-1.5B-Instruct_multi-prefill-seq_q8_ekv4096.litertlm` (descargado, SHA `faa60663…dc9` verificado) en el dispositivo.
  2. `automationModelMode=specificModel`, `automationModelPath=<archivo>`.
  3. Ejecutar batería de `03_GEMMA_QWEN_DIFFERENTIAL.md` (12 mensajes).
  4. En paralelo: persona base por defecto cuando `personal-retriever` devuelve 0 candidatos (`notification_draft_writer_personal_prompt.part.dart` — estilo del dueño, no hechos; nunca frases fijas).
- Riesgo: 1.5B q8 = 2.2 GB RAM catálogo; medir RSS al cargar. TTFT esperado 15–30 s en CPU de este SoC.
- Aceptación: 12/12 mensajes sin eco ni repeated_chars; TTFT medido y consistente; RAM estable.

## P1-2. Consolidar autoridad térmica en Kotlin (cierra B10)

- Problema: dos umbrales térmicos en dos capas pueden divergir.
- Solución: Dart consulta un único helper (ya existe `LanguageAssistService.thermalStatus`); eliminar la comparación `>=4` de los 3 archivos Dart y exponer `thermalGateAllows()` desde Kotlin (admite/degrada/bloquea por peso de modelo). Conservar el criterio actual: CRITICAL bloquea; SEVERE solo livianos.
- Archivos: `notification_event_router_thermal.part.dart`, `conversation_reply_flow.dart:145`, `conversation_reply_composer.dart:128`, `InferenceThermalGuard.kt`, handler de `thermalStatus`.
- Riesgo: bajo (mismo criterio, un solo dueño).

## P2-1. Warm-idle por actividad, no solo por reloj (cierra B11)

- Problema: conversaciones con >90 s entre mensajes pagan cold start 3.5–13.9 s.
- Solución: si hay conversación con burst reciente (<10 min), retener engine hasta 5 min; si no, 90 s actual.
- Archivos: `NanoModelRuntimeSupervisor.scheduleWarmUnload` + señal de actividad desde Dart.
- Aceptación: dos mensajes separados 3 min no recargan (log `ensure loaded=true`).

## P2-2. Verificar chat manual contra QualityGate (cierra B13)

- Problema: chat manual no usa `ConversationReplyQuality`.
- Solución: si el test manual muestra ecos en chat, aplicar el mismo gate antes de persistir la respuesta del chat (no el de automatización completo).
- Archivos: `chat_inference_coordinator.dart` / listener onInferenceSuccess.
- Riesgo: bajo; no bloquear si la respuesta es legítima (excepción de saludos ya existe).

## P2-3. Consolidar selección GPU/CPU (cierra parte de 04.2)

- Solución: Kotlin decide (tamaño de paquete + OpenCL); Dart solo informa preferencia. Eliminar el doble intento en `_initializeLiteRt` si el supervisor ya reintenta.
- Aceptación: un único log `backend=` por carga.

## P3-1. Probar Gemma 4 E2B con medición (cierra B12)

- Solución: intentar carga manual con `dumpsys meminfo` antes/durante; si OOM, marcar en catálogo como no apto para este dispositivo (gate por RAM disponible, no por tier).

## P3-2. Test multi-turno 100 turnos (criterio de éxito del encargo)

- Manual (usuario). Registrar por turno TTFT/tok-s/RAM/canonical. Buscar: crash, OOM, echo, doble envío, fuga.

## NO hacer (durante remediación)

- No agregar delays/timeouts como solución.
- No debilitar guardas de calidad para "que pase".
- No eliminar MNN ni GGUF hasta: (a) 1.5B validado, (b) confirmar que chat GGUF no se usa, (c) Whisper sigue servido.
- No introducir llama.cpp como segundo motor nuevo.
