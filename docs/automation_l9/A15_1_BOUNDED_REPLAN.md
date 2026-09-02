# A15.1 — Bounded Replan + Cross-App Recovery

> Estado: recuperación acotada en el TaskOrchestrator — clasificación tipada de
> fallos, presupuestos, reintento y detección de loops. Replan no es restart.

## Principio

```
REPLAN != RESTART

Preserva:
- IntentSpec original inmutable
- pasos completados verificados
- TaskValues tipados producidos
- governance en cada nuevo candidato
```

## Clasificación tipada de fallos (`TaskFailureKind`)

- `recoverable` — transitorio o de ruta (writeFile/openUrl falló): reintentar es
  seguro.
- `terminal` — denegado, sin datos, cancelado, sin progreso (sin notificación,
  sin URL, sin texto fuente): NO replan.
- `none` — no es un fallo.

## Presupuestos acotados

- `maxAttemptsPerStep` (default 2) — reintentos por paso.
- `maxReplansPerTask` (default 2) — replans totales por tarea.

Un paso recuperable se reintenta hasta el presupuesto. Los dependientes no se
ejecutan si el paso no completó. Los pasos completados (y sus TaskValues) se
preservan — no se recomputan.

## Detección de loops

Firma del reintento: mismo `reason` + mismo estado → detener. No hay
`tap → replan → tap → replan` infinito. Un reintento solo procede si algo
cambió (nueva ruta, nueva evidencia).

## Qué es recuperable vs terminal

| Fallo | Recuperable |
|-------|-------------|
| writeFile false | sí (reintento) |
| openUrl false | sí (reintento) |
| sin notificaciones | no (terminal) |
| sin URL en texto | no (terminal) |
| governance denied | no (nunca se bypassa) |

## Ruta RemoteInput → UI (ya en A14.7)

La recuperación RemoteInput→UI (REPLY_UNAVAILABLE → launch app → ScreenGraph)
ya está en el routing dinámico de A14.7/A14.8, no se duplicó aquí.

## Integración

El recovery vive dentro de `TaskOrchestrator.run`, que el seam `execute()`
(A15.0) ya usa. Un solo camino de orquestación — no hay `RecoveringTaskOrchestratorV2`.

## Seguridad / honestidad

- Nunca replan un `denied`/`cancelled` (governance no se bypassa).
- El dato intermedio preservado sigue siendo DATO, nunca instrucción.
- Solo la finalización verificada alimenta memoria/NanoFlow.
