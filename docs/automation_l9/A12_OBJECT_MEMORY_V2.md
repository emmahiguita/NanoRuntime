# A12 — ObjectMemory V2 (memoria contextual verificada)

> Estado: IMPLEMENTADO · WIRED (coordinator/perception source usan la API) ·
> DEVICE-VERIFIED: N/A (puro Dart).

## Propósito

Evolucionar la memoria de objetos UI de "selector funcionó" a evidencia
CONTEXTUAL: package + appVersion + screenSignature + semanticTarget + selector +
contadores + confidence decay, preservando SOUND learning.

## Cambios V2

- `UiObjectKey` + `screenSignature` (firma de pantalla) + `semanticTarget`
  (role esperado). Contexto liga el target al layout/estado.
- `UiSelectorEvidence` + `screenSignature` (dónde se verificó el selector).
- `UiObjectEntry` + `consecutiveFailures`.
- `NanoObjectMemory.resolve` → miss si `consecutiveFailures >= 2` (no actuar
  sobre memoria stale).
- `recordSuccess` resetea `consecutiveFailures`; `recordFailure` lo incrementa.
- `confidence(key, {now})` con decay temporal: >7 días 0.8, >30 días 0.5.
- Persistencia retrocompatible (JSON legacy sin contexto sigue parseando).

## SOUND learning (preservado)

Solo `recordSuccess` (éxito verificado) memoriza. `completedUnverified`/fallo no
entrenan éxito. Un fallo degrada confianza; fallos consecutivos invalidan hasta
nuevo éxito.

## Seguridad

La memoria demuestra target/navegación histórica; NO otorga autoridad. Ninguna
evidencia de memoria amplía el IntentSpec (A11). La memoria stale no se actúa.

## Rendimiento

Lookup de mapa constante. Sin IO en el hot path (persistencia explícita).

## Limitaciones

- Confidence decay es heurística simple (7/30 días), no calibrada por benchmark.
- La confianza por selector (en vez de por entry) queda documentada como futura.
- La integración de screenSignature desde ScreenGraph se completa cuando exista
  ScreenGraphCandidateProvider (el dominio está listo).

## A13 seam

La memoria contextual alimentará Skills/multiagentes (roles lógicos) sin acoplar
memoria a orquestación.
