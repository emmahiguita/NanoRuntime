# A15.2 — Validated LLM Decomposition

> Estado: vocabulario finito + validador de descomposición LLM implementado.
> El LLM amplía cobertura semántica; NO recupera poder de bajo nivel.

## Regla estricta

```
LLM PUEDE producir (semántica finita):
read_notification, extract_url, open_app, open_url,
observe_screen, write_file, reply_message

LLM NO puede producir:
tool names arbitrarios, shell, packages, selectores,
coordenadas, raw intents, privilegios
```

## Qué se implementó

- `task_step_vocabulary.dart` — `kAllowedTaskSemantics` (conjunto finito) +
  `validateSemantics()` + `kSemanticInputs` (params por semántica).
- `TaskPlanner.planFromSemantic(goal, specs)` — recibe `SemanticStepSpec[]` del
  LLM, valida contra el vocabulario + `TaskPlan.validate()` (sin ciclos,
  maxSteps) y construye el TaskPlan o devuelve null (rechazo).

## Flujo

```
LLM produce SemanticStepSpec[]  (solo semántica finita)
        ↓
validateSemantics()  ← rechaza shell/tool arbitrario
        ↓
TaskPlan.validate()  ← rechaza ciclos/maxSteps
        ↓
TaskOrchestrator.run()  ← Candidate-First decide CÓMO ejecutar cada paso
```

Candidate-First sigue siendo quien decide cómo se hace cada paso (qué
CandidateAction, qué selector, qué herramienta). El LLM solo decide QUÉ.

## Seguridad

- Un paso con semántica fuera del vocabulario → plan rechazado (null).
- El contenido observado (notificación/pantalla) nunca se convierte en
  semántica nueva; solo el IntentSpec original define el alcance.
- La salida del LLM es DATO de planificación, validada; nunca autoridad.

## Pendiente

- Cablear el LLM real (runtime) para que produzca `SemanticStepSpec[]` cuando
  no hay template determinista. El validador ya está; falta el prompt/parseo
  de descomposición + invocación del runtime en `TaskPlanner.plan()`.
