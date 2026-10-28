# 02 — MNN FORENSICS

Pregunta del encargo: ¿qué hacía MNN bien, qué se perdió, qué no debe volver?

## Estado real

MNN 3.6.1 compilado vía CMake (`android/app/src/main/cpp/CMakeLists.txt`): `MNN_BUILD_LLM ON`, `MNN_BUILD_LLM_OMNI ON`, `MNN_OPENCL OFF` (CPU verificado), `LLM_USE_JINJA` activo (definición privada en target `llm`). Librerías en APK: libMNN.so, libllm.so, libnanomnn.so, libMNN_Express.so, libMNNOpenCV.so, libMNNAudio.so (verificado en base.apk del dispositivo).

Paquete activo: `Qwen2.5-Omni-3B-MNN` con `llm_config.json` de solo texto (`is_visual:true`/`is_audio:true` en el json, pero el JNI prefiere `llm_config.json` para NO cargar visual/audio/talker, ~2.3 GB extra — comentario en `mnn_jni.cpp` load()).

## Qué hacía bien MNN (antes de esta sesión)

1. **Calidad de respuesta**: 3B Omni > 0.6B q4 para español natural. Evidencia indirecta: era el modelo activo de chat y automatización del usuario.
2. **Multimodal empaquetado**: el paquete trae visual/audio/talker; perfil texto carga solo el LLM (decisión correcta de Nano).
3. **Aislamiento simple**: un modelo, una sesión, sin HTTP, sin proceso separado — simplicidad operativa frente a GGUF.

## Qué hacía mal (evidencia, corregido 2026-10-16)

1. **Sin reutilización de KV**: `mnn_jni.cpp` llamaba `model->reset()` + `response(prompt)` por turno → prefill COMPLETO del historial cada mensaje. Medido en repo: "MNN CPU tardó 44.8 s en prefill" (`notification_draft_writer_capacity.part.dart:5`), TTFT 111 s en CPH2557 (`routed_llm_engine_client.dart:29`). FIX: reuse_kv + prefill delta + prompt cache en JNI.
2. **ChatML manual en Dart**: `_chatMl()` en `mnn_stream_lifecycle.dart` ensamblaba `<|im_start|>` a mano (violaba la regla "la plantilla es del modelo"). FIX: mensajes estructurados → jinja nativo inyectado en `set_config` (el paquete Omni NO trae template en config.json — verificado en el archivo del dispositivo).
3. **CPU fijo 4 hilos** en SoC 2+6 (razonable, no era el cuello principal).
4. **Sin fallback de backend** (MNN_OPENCL OFF por diseño; correcto en MT6833 según skill nano-mnn-runtime).

## Comparación objetiva MNN vs LiteRT-LM en Nano

| Capacidad | MNN (Omni 3B) | LiteRT-LM (Qwen3 0.6B / 1.5B) | Ganador |
|---|---|---|---|
| Calidad español (3B vs 0.6B) | Alta | Baja (medido: echo, repeated_chars) | MNN |
| TTFT primer turno | 44.8–111 s (CPU, pre-fix) | 4.4–12.5 s | LiteRT |
| Reutilización de KV multi-turno | No tenía; ahora sí (JNI propio) | Nativa en `Conversation` (`LiteRtGeneration`) | LiteRT |
| Plantilla/tokenizer nativos | Jinja inyectado por Nano (el paquete no la trae) | Dentro del .litertlm (`Conversation` aplica template) | LiteRT |
| GPU/NPU | OFF (CPU only) | GPU OpenCL + fallback CPU | LiteRT |
| Multimodal (imagen/audio) | Paquete lo trae (no activo en perfil texto) | .litertlm con vision encoder (no usado en Nano) | Empate/UNVERIFIED |
| Tool calling / gramáticas | No usado | No usado | — |
| Estado de sesión/cancel | Atómico JNI (mutex + flag) | Engine/Conversation nativos | LiteRT |

## Funciones útiles a conservar de MNN

- Ruta de calidad cuando el usuario quiera respuestas largas/naturales en chat manual (3B), asumiendo TTFT alto en este SoC (documentarlo en UI).
- El empaquetado verificado con checksums (`*.integrity.json`) — patrón de instalación que ya comparte con LiteRT.
- El modelo de perfil texto (llm_config.json) como patrón para no cargar modalidades no usadas.

## Funciones que NO deben recuperarse

- Prefill completo por turno (ya resuelto).
- ChatML manual en Dart (ya resuelto).
- MNN para automatización en MT6833: TTFT de minutos no es viable para respuestas de notificación.

## Lo que LiteRT ya resuelve mejor

- Conversation + KV con reuso exacto, budget de contexto por paquete, métricas TTFT/tok-s, carga 3.5 s (CPU), decode 15 tok/s (CPU) en 0.6B — todo medido en dispositivo esta sesión.
