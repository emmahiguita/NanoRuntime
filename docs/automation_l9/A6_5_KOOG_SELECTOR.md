# A6.5 — Koog Candidate Selector (ambiguity only)

> Estado: IMPLEMENTADO (aislado) · NO WIRED (planner productivo intacto).

## Por qué Koog es solo para ambigüedad

`CandidateRanker` (determinista) resuelve el caso claro sin modelo. Koog solo
entra cuando el ranker produce `AmbiguousCandidates`. Filosofía Nano:
"abre Chrome" / "abre Bluetooth" / "volver" → 0 LLM. "abre Whats" (WhatsApp vs
WhatsApp Business) → Koog elige `candidateId`.

```
CandidateSet → CandidateRanker
  ├ SelectedCandidate → devolver (0 LLM)
  ├ NoCandidate → devolver (0 LLM)
  └ AmbiguousCandidates → KoogCandidateSelector (≤1 LLM)
```

## Por qué el ranker determinista va primero

La selección determinista es barata, predecible y no consume presupuesto móvil.
El modelo solo entra para resolver una ambigüedad real que el grounding no
puede decidir sin contexto.

## Por qué el LLM no es evidencia

El output del modelo es DATA. El `CandidateSet` es la autoridad. Koog solo puede
referenciar un `CandidateId` existente; no crea acciones, tools, packages,
selectors, intents ni coordenadas.

## Protocolo de output

Único output aceptado: `{"candidateId":"<id>"}` o `{"candidateId":null}`
(abstención). Cualquier otra cosa (ToolCall JSON, selector, malformed) →
`InvalidCandidateSelection`.

## Rechazo de ID desconocido

`candidateId` fuera del set → `InvalidCandidateSelection` (no se crea candidato).
`app:launch:evil.fake` → rechazado.

## Semántica de abstención

`{"candidateId":null}` → `AmbiguousCandidates` se preserva (no es fallo). La
resolución humana puede cerrar la ambigüedad después.

## Estado del Koog legado

`koog.dart` (`PlanGenerator`/`KoogStep`/`Koog.run`) queda intacto: solo lo usan
los tests (`koog_test.dart`), sin callers de producción. Migración strangler: se
eliminará cuando no queden callers. `KoogCandidateSelector` es un componente
nuevo que usa `LLMEngineClient` (mismo runtime local), no el `PlanGenerator`.

## Relación con A13 (multiagentes)

En A13 Koog podrá subir de "selector de ambigüedad" a coordinador de roles
lógicos, SIEMPRE dentro del mundo que Nano ya demostró que existe: razona sobre
candidatos grounded, nunca construye acciones.

## LLM call budget

- ganador determinista → 0 llamadas.
- ambigüedad → ≤1 llamada Koog.
- sin loops recursivos de selección.
