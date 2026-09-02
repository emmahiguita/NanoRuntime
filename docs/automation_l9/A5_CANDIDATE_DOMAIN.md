# A5 — Candidate-First Domain Foundation

> Estado: IMPLEMENTADO (domain) · NO WIRED (sin callers de producción) ·
> DEVICE-VERIFIED: N/A (puro Dart).

## Propósito

Introduce la representación tipada de "una acción que Nano realmente sabe cómo
podría ejecutar", separada del `ToolCall` (comando del ejecutor).

```
PLANNING:  CandidateAction ──selección──▶ ToolCall
EXECUTION: ToolCall ──dispatcher──▶ executor
```

`ToolCall` responde "qué debe ejecutar"; `CandidateAction` responde "por qué es
real, de dónde salió, cómo de grounded está, qué canal la ejecutaría, qué
probará que funcionó, qué riesgo tiene".

## Tipos

- `CandidateId` — identidad determinista (`app:launch:com.android.chrome`).
- `ActionChannel` — mecanismo de ejecución (15 valores; presencia ≠ disponible ≠ autorizado).
- `ActionEvidenceSource` / `ActionEvidence` — proveniencia de grounding (sin `llm`).
- `CandidateAction` — candidato grounded inmutable.
- `CandidateSet` — colección sin IDs duplicados (sin ranking, sin ejecución).
- `CandidateSelection` — sealed: Selected / Ambiguous / NoCandidate.
- `CandidateProvider` — puerto de extensión (interface; sin implementaciones).

## Invariantes

- id/semanticAction/tool no vacíos.
- `groundingConfidence` y `expectedSuccess` ∈ [0,1].
- evidence no vacía (un `CandidateAction` SIEMPRE es grounded).
- `args`/`evidence`/`requiredCapabilities` inmutables (unmodifiable).

## CandidateAction vs ToolCall

| | CandidateAction | ToolCall |
|---|---|---|
| capa | planning | execution |
| pregunta | por qué es real | qué ejecutar |
| argumentos | `args` canónico | `args` + legacy getters |
| evidence | sí (proveniencia) | no |
| grounding | explícito | implícito |

## Grounding vs expectedSuccess

- `groundingConfidence`: la acción se refiere a un target REAL/disponible.
- `expectedSuccess`: probabilidad de que el camino complete. Distintas.

## Por qué el LLM no es evidencia

El modelo puede rankear/razonar sobre candidatos, pero no hace real una acción.
La evidencia de grounding viene de hechos observados (PackageManager, SystemGraph,
SystemIntentCatalog, NanoFlow, ObjectMemory, Accessibility).

## Por qué producción no migra aún

A5 es dominio puro. No cambia el comportamiento de planificación ni el
AutomationCoordinator. "Sin caller de producción todavía" no es dead code: A6 lo
consume inmediatamente y está cubierto por tests.

## Limitación de seguridad explícita

A5 valida ESTRUCTURA (campos, confidences, evidence no vacía). NO puede probar
que `com.fake.chrome` no exista: el dominio no consulta PackageManager. La
PROVENANCIA la garantiza el provider (A6): solo el provider de apps instaladas
emitirá `ActionEvidenceSource.packageManager`. A6 probará el rechazo del package
fabricado.

## Plan de integración A6

- `DeterministicCandidateProvider`, `InstalledAppCandidateProvider`,
  `SystemIntentCandidateProvider`, `NanoFlowCandidateProvider`,
  `NotificationCandidateProvider` (cuando esté listo).
- `CandidateActionGenerator` (agregación de providers).
- `CandidateRanker` determinista + manejo de ambigüedad.
- Adapter `CandidateAction → ToolCall`.
- Primer pipeline end-to-end aislado.
