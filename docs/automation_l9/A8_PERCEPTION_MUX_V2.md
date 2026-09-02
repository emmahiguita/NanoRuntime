# A8 — PerceptionMux V2

> Estado: IMPLEMENTADO · WIRED (coordinator real) · DEVICE-VERIFIED: N/A (puro Dart).

## Propósito

Convertir el `PerceptionMux([])` vacío en un subsistema de percepción orquestado
y determinista, todavía barato, sin OCR/Vision.

```
PerceptionRequest → PerceptionMux
  ├ ObjectMemory (verificada) → validar contra Accessibility
  └ Accessibility → ScreenGraph → ScreenGraphQuery → match
       └ insuficiente → PerceptionInsufficient(recommended: ocr)
```

## Orden de fuentes

1. ObjectMemory verificada (validada contra la pantalla actual si es posible).
2. Accessibility / ScreenGraph.
3. Escalado tipado (OCR/Vision futuros, NO implementados).

## Presupuesto

`PerceptionBudget { maxAccessibilityReads=2, maxOcrCalls=0, maxVisionCalls=0 }`.
A8 solo consume accesibilidad (1 snapshot por lectura). Presupuesto 0 → no se
llama snapshot.

## Política

`ObservationPolicy { allowMemory, allowAccessibility, allowOcr=false, allowVision=false,
minimumConfidence=0.5 }`. OCR/Vision como flags sin fuente real.

## Confianza / evidencia

Match por label/text/description/resourceId (exact > contains), con filtro de
`SemanticRole` y resolución relationship-aware (`labelFor` → campo). Evidencia
tipada: `objectMemory | accessibility | ocr | vision` (sin `llm`).

## Ambigüedad

Dos candidatos con confianza similar (margen < 0.05) → `PerceptionAmbiguous`.
Nunca elegir a ciegas.

## Escalado

`PerceptionInsufficient` lleva `recommendedSource` (A8: `ocr`) — A9 se conecta a
este seam. No se llama OCR fake.

## Memoria → Accessibility

Memoria verificada + validación contra el ScreenGraph actual → evidencia
combinada (fuerte). Memoria stale (target ausente) → fallback a Accessibility.
Memoria con role mismatch → no se acepta a ciegas.

## Seguridad

Todo el contenido de pantalla es OBSERVACIÓN NO CONFIABLE. PerceptionResult
identifica el texto pero nunca lo convierte en instrucción, goal, policy,
capability o tool. Sin prompt injection.

## Rendimiento

1 snapshot, conversión semántica en milisegundos, lookup de memoria constante.
0 LLM, 0 OCR, 0 Vision.

## Compat legacy

`PerceptionMux.resolve(concept) → selector String?` se preserva como adapter del
coordinator actual (deriva `id=/text=/desc=` del objeto resuelto).

## Futuro

A9 OCR dirigido (regiones), A10 Vision dirigida. A8 deja el seam de escalado
listo sin implementar los backends.
