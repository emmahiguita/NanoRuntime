# A15 — Voz + Memory Budget + Benchmark

> Estado: DOMAIN COMPLETE · BACKENDS STT/TTS NOT DEVICE-READY · BENCHMARK FÍSICO
> PENDIENTE (device).

## Voz

`SpeechToText` (mic→texto), `TextToSpeech` (texto→audio), `VoiceSessionManager`
(ciclo STT → goal → automation → verified → TTS). REGLA DE HONESTIDAD: NO
anunciar éxito hasta que `AutomationResult.isVerifiedSuccess` (GoalVerifier
satisfied). Backends STT/TTS futuros (contratos aquí, sin implementación A15).

## Memory budget (HOT/WARM/COLD)

`ModelComponent { llm, vlm, ocr, stt, tts }` + `ResidencyState { hot, warm, cold }`.
Default: LLM hot (núcleo), OCR warm, VLM/STT/TTS cold. La automatización básica
funciona SIN Vision cargada. Sin residencia permanente de modelos pesados.

## Benchmark físico

Pendiente (requiere device). Las métricas objetivo (goal success rate, false
success = 0, unsafe/unauthorized rate, avg steps, p50/p95 latency, LLM calls,
candidate count, memory/NanoFlow hit rate, vision escalation rate) se miden en
device. El seam C14 (`C14Execution`) ya captura parte (path/llmLatency/
verification/goalSuccess); A15 no reescribe el benchmark.

## Filosofía Nano (cierre L9)

Mínima inteligencia + mínimo privilegio + mínimo efecto secundario. "abre Chrome"
→ 0 LLM; visión solo bajo demanda; gobernanza antes de privilegios. La
arquitectura L9 queda: SystemGraph (saber), Candidate-First (acciones reales),
Koog (ambigüedad), ScreenGraph/PerceptionMux (ver), Governance (autorización),
ObjectMemory V2 (memoria), Skills/agentes (capacidades), MCP/Shizuku (extensión
tipada).

## Limitaciones finales

- Vision backend, STT/TTS, MCP server y Shizuku: contratos listos, backends no
  device-ready (se integran como fuentes/backends sin cambiar el corazón).
- Benchmark físico y validación on-device pendientes.
- OCR bounds `imageRelative → screenAbsolute` retro-fit pendiente (documentado
  en A9/A10).
