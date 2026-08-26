# A15.0 — Typed Cross-App Task Orchestration

> Estado: núcleo tipado implementado — TaskPlan/TaskStep/TaskValue + TaskPlanner
> determinista + TaskOrchestrator con data flow. Falta wiring al coordinator y
> descomposición LLM (siguiente paso).

## Principio

```
User Goal → IntentSpec → TaskPlan → TaskStep[] (semántica) → Candidate-First
          → Governance → Execute → Verify → typed output → next TaskStep
```

- NO es un segundo AutomationCoordinator.
- NO es un workflow engine libre de LLM.
- El modelo decide SEMÁNTICA (pasos/variables); Candidate-First decide CÓMO.

## Modelo tipado

- `TaskValue` (sealed): `TextValue`, `UrlValue` (http/https), `FilePathValue`,
  `PackageValue`, `NotificationValue`. Nunca Map arbitrario.
- `TaskValueId` — referencia estable a un valor intermedio.
- `TaskStep` — semanticAction finito, `inputBindings` (param→TaskValueId),
  `produces`, `dependencies`.
- `TaskPlan` — `validate()` (sin ciclos, dependencias conocidas, maxSteps),
  `ordered` (topológico).
- `TaskStepResult` — completed / completedUnverified / denied /
  needsConfirmation / needsMoreEvidence / failed (sin bool genérico).

## TaskPlanner (templates deterministas, 0 LLM)

- "guarda el enlace de X" → readNotification → extractUrl → writeFile.
- "abre el enlace de X" → readNotification → extractUrl → openUrl.

Descomposición LLM = siguiente fase (solo semántica finita, nunca ToolCall).

## TaskOrchestrator (data flow tipado)

Ejecuta pasos en orden topológico, transportando TaskValues entre dominios:
```
readNotification → TextValue → extractUrl → UrlValue → writeFile(FileExists) / openUrl
```
Un paso no-completado detiene los dependientes (no pasos huérfanos).

## Seguridad (innegociable)

- Dato intermedio = DATO, nunca instrucción. El texto de notificación no se
  convierte en comando/intent/privilegio.
- URL solo http/https (A14.9). No intent://file://content://javascript.
- Governance en cada paso efectivo; verificación en cada transición.
- Solo la finalización VERIFICADA entrena memoria/NanoFlow.

## Pendiente (siguiente paso)

1. Wiring al `AutomationCoordinator` (sección 57): simple → single-step
   CandidateFirstPlanner; complejo → TaskOrchestrator.
2. Descomposición LLM validada (vocabulario finito, sin ciclos, maxSteps).
3. Telemetría C14-B (taskSteps, crossDomainTransitions, zeroLlmTask, ...).
4. Replan bounded (RemoteInput→UI, percepción escalada).
