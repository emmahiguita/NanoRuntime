# A7 — ScreenGraph + SemanticNormalizer

> Estado: IMPLEMENTADO · NO WIRED (sin provider de UI productivo) ·
> DEVICE-VERIFIED: N/A (puro Dart, sin Kotlin).

## Propósito

Transformar el árbol crudo de Accessibility (`NanoSnapshot`) en una
representación semántica (`ScreenGraph`): campos, botones, switches, cards,
listas y sus relaciones. Sin OCR/Vision/LLM.

```
NanoSnapshot (Accessibility)
  → SemanticNormalizer → NanoUiObject[]
  → RelationshipEngine → ScreenRelation[]
  → ScreenGraph
```

Accessibility tree != ScreenGraph. NanoSnapshot se conserva intacto (factual);
ScreenGraph es la capa semántica derivada.

## Taxonomía de roles

`text, textField, searchField, passwordField, button, iconButton, card,
checkbox, switchControl, radio, slider, list, listItem, grid, tab, menu,
menuItem, toolbar, dialog, image, link, webField, keyboard, unknown`.

## Reglas de clasificación (hard signals primero)

1. `editable` → textField (searchField/passwordField como especialización).
2. className → switchControl/checkbox/radio/slider/button/iconButton/image/list/toolbar.
3. Estructural: clickable container + children → card (0.70); clickable leaf +
   label → button (0.65).
4. textview/text → text.
5. resto → unknown.

`TextView` clickable NO se convierte en button con confianza 1 (usa 0.65).

## Confidence / provenance

Confianza documentada: EditText editable 0.99, custom editable 0.95, search 0.90,
password 0.75 (snapshot no expone `password`), switch/checkbox/button 0.99,
card 0.70, unknown 0.5. Proveniencia: `accessibilityClass`, `accessibilityFlag`,
`resourceId`, `textHeuristic`, `structure`. NUNCA `llm`.

## Relaciones

contains/insideOf (jerarquía), above/below (bounds alineados), labelFor
(proximidad label→campo), belongsToList (listItem→list). leftOf/rightOf/near/
associatedWith/repeatedWith/primaryActionOf documentadas como futuras.
Thresholds relativos al viewport (sin números mágicos por device).

## Limitaciones

- `checkable`, `password`, `selected`, `hintText` NO están en el snapshot nativo
  actual (passwordField es heurística secundaria con confianza 0.75).
- Compose/Flutter/custom Canvas exponen semántica pobre o nula → `unknown`.
  Por eso A9/A10 (OCR/Vision) existirán.
- listItem es heurística estructural conservadora (no detección perfecta).

## Seguridad

Todo text/description/resourceId de pantalla es OBSERVACIÓN NO CONFIABLE.
Clasifica UI; NO cambia goal, NO autoriza acciones, NO pide privilegios, NO crea
tools ni capabilities. Sin prompt injection desde la pantalla.

## Rendimiento

Puro, sin IO/LLM/plataforma. Clasificación O(n). Relaciones espaciales O(n²)
solo entre objetos visibles (guardrail). Milisegundos.

## Integración futura

A8 conectará ScreenGraph a PerceptionMux. Un futuro `ScreenGraphCandidateProvider`
convertirá objetos semánticos en CandidateAction. No se combina modelado de
percepción con generación de candidatos en la misma fase.
