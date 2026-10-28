# 07 — LATENCY AUDIT (medido en dispositivo)

## Pipeline de latencia del turno (T0→T10)

```
T0 notificación recibida (event_channel)
T1 admisión + burst + dedupe
T2 draft:queue → ensureReady (arranque de motor si frío)
T3 carga del modelo (cold start) / reuso (warm)
T4 presupuesto de contexto (LiteRtContextBudget)
T5 prefill
T6 primer token (TTFT)
T7 decode → último token
T8 calidad (echo/repetition) + regeneración opcional
T9 guardas de envío
T10 envío (accessibility) + persistencia canonical
```

## Mediciones reales (capturas logcat de esta sesión)

| Fase | MNN Omni 3B CPU (pre-fix) | LiteRT 0.6B GPU (Mali G57) | LiteRT 0.6B CPU (post-fix) |
|---|---|---|---|
| Carga modelo | ~10 s+ (no medido) | **13.9 s** (incluye compilación OpenCL) | **3.5 s** |
| TTFT | 111 s (documentado en código) | 7.4–12.5 s | **4.4–9.2 s** |
| Decode | ~2 tok/s (est.) | 0.8–5.4 tok/s | **3.7–15.1 tok/s** |
| Calidad | pasaba | echo / repeated_characters → regeneración (+9–13 s) y rechazo final | ídem GPU (mismo modelo) |

Fuente: `logcat_live.txt` — `LiteRtChannel: initialized ms=3452`, `completed ... metrics={ttftMs=4663, tokensPerSec=15.12, totalTokens=128, activeBackend=cpu}`, etc. Comentarios de código con medidas previas: `routed_llm_engine_client.dart:29` (111 s MNN), `notification_draft_writer_capacity.part.dart:5` (44.8 s prefill MNN).

## Dónde se va el tiempo (causas raíz)

1. **Cold start de motor por turno espaciado**: warm-idle 90 s → conversaciones con >90 s entre mensajes pagan carga (3.5 s CPU / 13.9 s GPU). Medido: `[draft:start]`→`initialized ms=13886` en el turno de las 14:46.
2. **Regeneración por calidad**: cada rechazo (echo/repeated_chars) añade OTRO turno completo de inferencia (+4.4–13 s). Turno 14:46: 10.8 s + 9.8 s + rechazo = 47 s hasta fallo final (`lastBatchLatencyMs=47181`).
3. **Fallback de conocimiento (web)** tras rechazo: añade ~5 s y suele fallar (`BrowserAiGateway status=failed`, `no compatible MCP AI query tool`) → silencio final.
4. **GPU lenta en modelos memory-bound**: Mali-G57 MC2 OpenCL 0.8–5.4 tok/s vs CPU 15.1 tok/s en el MISMO modelo → política CPU para <1 GB (aplicada).
5. **MNN sin KV reuse (histórico)**: 44.8 s prefill por turno → corregido (delta prefill).
6. **Bloqueo térmico (histórico)**: SEVERE falso de ColorOS difería turnos indefinidamente (`deferred_before_admission`) → corregido (SEVERE degrada).

## Oportunidades restantes

- Mantener el engine caliente más tiempo cuando hay conversación activa (warm-idle por actividad de chat, no solo tiempo) — reduce el cold start de 3.5 s.
- Evitar la regeneración cuando el rechazo es del modelo débil: con 1.5B/coherente, la tasa de regeneración debería caer a ~0.
- Cola explícita con deadline (hoy el mutex hace esperar sin visibilidad de cuánto queda).
