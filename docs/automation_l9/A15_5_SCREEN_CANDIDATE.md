# A15.5 — ScreenGraphCandidateProvider (percepción → planificación)

> Estado: WIRED (pipeline productivo) · DEVICE-VERIFIED: N/A (puro Dart, snapshot
> fake en tests).

## Propósito

Cierra el gap entre ScreenGraph (A7, percepción semántica) y Candidate-First
(A5/A6, planificación grounded). Convierte objetos semánticos de UI en
CandidateAction (tap, channel accessibility, evidencia accessibility).

## Flujo

```
Goal "toca Enviar"
→ IntentSpec (writeUi)
→ CandidateActionGenerator
   → ScreenGraphCandidateProvider (snapshot → ScreenGraph → query → match)
→ CandidateAction(tap, selector=text=Enviar, channel=accessibility)
→ governance (firewall/critic/broker)
→ adapter → ToolCall → executor → verify
```

## Grounding

El candidato lleva `evidence: accessibility` (objeto real del árbol). El
contenido de pantalla es OBSERVACIÓN NO CONFIABLE: identifica el target, no
autoriza. `requiredCapabilities: interactAccessibility` → el broker/critic
deniega si Accessibility no está disponible.

## Integración

Añadido al `candidateFirstPlannerProvider` (después de app/intent/nanoFlow).
Los goals deterministas (app/intent) siguen resolviendo 0 LLM por providers
previos; este provider cubre la interacción UI.

## Limitaciones

- Solo `tap` (no write/scroll/long-press por objeto todavía).
- `request.goal` como concept (sin expectedRole tipado en CandidateRequest).
- Requiere Accessibility disponible (snapshot).

## Estado L9 post-A15.5

La cadena queda completa: SystemGraph (saber) → Candidate-First + ScreenGraph
(acciones reales) → Koog (ambigüedad) → Governance (autorización) → Executor →
Verify → Memory.
