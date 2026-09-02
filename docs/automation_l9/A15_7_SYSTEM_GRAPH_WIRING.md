# A15.7 — SystemGraph real cableado al Candidate-First

> Estado: WIRED (planner productivo) · DEVICE-VERIFIED: N/A (async graph en
> device).

## Propósito

Reemplazar el `_intentGraph()` estático (solo 3 capabilities de intent) por el
`SystemGraph` REAL (async): device profile + apps + probes de capability
(accessibility/notification/Linux). El candidate pipeline y el governance ahora
validan capabilities factuales.

## Cambios

- `systemGraphProvider` = `FutureProvider<SystemGraph>` (build del
  `systemGraphBuilderProvider`, cacheado).
- `CandidateFirstPlanner` ahora recibe `generatorBuilder(graph)` +
  `getGraph()` (lazy loader): carga el graph en `plan()`, construye el generator
  con el graph (SystemIntentCandidateProvider) y pasa el graph al governance
  (broker/critic validan availability factual).
- Eliminado `_intentGraph()` estático.

## Efecto

"abre Bluetooth" ahora requiere `openBluetoothSettings` factualmente disponible;
"abre Chrome" requiere `launchApps`; "tap" requiere `interactAccessibility`. El
critic deniega capabilities no disponibles (antes el graph estático solo
declaraba intents).

## Seguridad

El graph real alimenta availability factual; no otorga autoridad (sigue el
IntentSpec/A11). El contenido observado no muta el graph.

## Limitaciones

- El graph se carga una vez (cacheado); refresh explícito pendiente de
  integration con un evento de refresh (A3 lo soporta).
- Sin metric de latencia del graph load en el trace C14 (future).
