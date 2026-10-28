# 06 — MEMORY AUDIT

## Medidas reales (sesión 2026-10-16, CPH2557)

- MemTotal 7.8 GB; **MemAvailable ~1.9 GB** durante las pruebas (medido `cat /proc/meminfo`).
- Modelos en disco (`run-as du`): Omni 3B 1.7 GB weight; gemma 2.6 GB; qwen3_0.6b 347 MB; LFM2.5 266 MB.
- LiteRT qwen3_0.6b cargado con GPU: proceso estable, carga 13.9 s (incluye compilación OpenCL); con CPU: 3.5 s.
- MNN Omni 3B cargado: sin medición RSS directa en esta sesión; el comentario JNI registra que el paquete completo (visual/audio/talker) excede el límite del proceso ColorOS/Athena — por eso se usa `llm_config.json` texto.

## Riesgos

1. **P1 — Gemma 4 E2B (2.6 GB) en RAM 8 GB con ~1.9 GB libres**: carga improbable sin zram thrash u OOM. No probar sin antes medir. UNVERIFIED.
2. **P1 — Warm retention vs RAM**: el supervisor conserva el engine hasta 90 s idle (menos bajo térmica). Con Qwen 1.5B q8 (~2.2 GB RAM según catálogo) la retención compite con el resto de la app. Ajustar idle timeout al tamaño del paquete si se adopta 1.5B.
3. **P2 — KV cache estática**: MNN reserva según `max_all_tokens` (default 2048); LiteRT según el paquete (qwen3 ekv1280). Sin ring buffers ni snapshot de sesión en Nano (LiteRT-LM los ofrece; no usados). No hay fuga dinámica conocida.
4. **P3 — Snapshot de sesión**: no implementado (PocketPal lo tiene). Con KV pequeño y warm-unload, volver a una conversación = full prefill. Coste medido: 4.4–12.5 s TTFT en 0.6B. No es fuga, es latencia.
5. **HYPOTHESIS — Fugas de callback JNI**: `LiteRtEngineOwner`/`MnnNative` destruyen referencias en terminal (`litertlm.cc` upstream usa DeleteGlobalRef); no se encontró fuga evidente en Nano, pero no hay test de 100 turnos. Pendiente del test multi-turno (FASE multiturno del encargo).

## Tabla de presupuesto orientativo (catálogo, no medido en RAM real)

| Modelo | sizeGb | ramGb (catálogo) | Viable en CPH2557 |
|---|---|---|---|
| qwen3_0.6b q4 | 0.32 | 1.0 | SÍ (medido) |
| LFM2.5-230M | ~0.27 | <1 | SÍ |
| Qwen2.5-1.5B q8 | 1.49 | 2.2 | CONDICIONAL (verificar RSS) |
| Qwen2.5-1.5B GGUF Q4_K_M | ~1.0 | ~1.5 | CONDICIONAL (ruta GGUF) |
| Omni 3B MNN | 1.7+ | >3 | SÍ pero TTFT alto |
| Gemma-4-E2B | 2.6 | >4 | DUDOSO (OOM probable) |
