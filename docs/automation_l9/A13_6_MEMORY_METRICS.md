# A13.6 — ObjectMemory → PerceptionMux + C14 observabilidad

> Estado: WIRED (split-brain eliminado) · DEVICE-VERIFIED: N/A (puro Dart).

## Split-brain encontrado

El coordinator consultaba memoria DIRECTAMENTE (`_objectMemory.resolve(key)`) y
luego el PerceptionMux (`mux.resolve(concept)`) sin memoria. Dos rutas
perceptivas, una instancia de memoria no compartida con el mux.

## Fix (Part A)

- `objectMemoryProvider` = `StateNotifierProvider<ObjectMemoryNotifier,
  NanoObjectMemory>` (ÚNICA instancia productiva, mutable via `replace`).
- `perceptionMuxProvider` inyecta `ObjectMemoryPerceptionSource` (getter de la
  instancia actual) junto a accessibility + OCR.
- El coordinator `_resolveSelectors` ya NO consulta memoria aparte: usa
  `mux.resolve(concept)` (memory-first + accessibility + OCR).
- `_recordMemory` notifica el notifier (`onMemoryUpdate`) para compartir la
  instancia actualizada.
- Percepción no entrena memoria (lookup no llama `recordSuccess`; solo el
  pipeline de verificación actualiza positivamente).

## Observabilidad (Part B)

`C14Execution` + `candidateCount`, `selectionMode` (deterministic/koog/
legacyFallback/none), `koogInvoked`, `legacyFallback`, `candidateLatency`.
`CandidateSelectionEngine.lastKoogInvoked` + `CandidateFirstPlanner` exponen
`SelectionMode` en el resultado.

`C14BenchmarkReport` + `legacyFallbackRate`, `zeroLlmRate`,
`koogInvocationRate`. Target futuro: legacyFallbackRate → 0; zeroLlmRate crece.

## Seguridad

Memoria sigue siendo evidencia, no autoridad. No modifica IntentSpec, no bypass
governance/Koog/Policy. Lookup no entrena.

## Rendimiento

Instrumentación con Stopwatch (sin tracing gigante). No añade LLM/percepción/
Android calls. Observa el path existente.

## Limitaciones

- Latencia de sub-fases (generation/selection/governance separadas) no medida
  individualmente (candidateLatency total).
- percepciónLatency no instrumentada aún (follow-up).
- Graph refresh explícito tras eventos de estado pendiente.
