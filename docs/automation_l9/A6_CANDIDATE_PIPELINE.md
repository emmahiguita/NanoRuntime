# A6 — Candidate Pipeline (providers + generator + ranker + adapter)

> Estado: IMPLEMENTADO (aislado) · NO WIRED (planner productivo intacto) ·
> DEVICE-VERIFIED: N/A (puro Dart, sin Kotlin).

## Providers implementados

| Provider | Fuente de verdad | Channel | Tool | Evidencia |
|---|---|---|---|---|
| DeterministicCandidateProvider | DeterministicFlowCatalog | deterministic | back, notifications | deterministicCatalog |
| InstalledAppCandidateProvider | InstalledAppCatalog | androidIntent | launch_app | packageManager |
| SystemIntentCandidateProvider | SystemGraph + SystemIntentCatalog | androidIntent | open_system | systemIntentCatalog, systemGraph |
| NanoFlowCandidateProvider | ExperienceCache (verified) | nanoFlow | (1 paso) | nanoFlow |

NotificationCandidateProvider: **DIFERIDO** — el layer de notificaciones actual
expone el key técnico como dato opaco dentro de un feedback Markdown legible; no
hay un contrato estructurado limpio de notificación (key + canReply + source) sin
parsear Markdown. Se reintroduce cuando el boundary de notificación sea tipado.

## Fuentes de verdad

Los providers dependen de `SystemGraph`, `SystemIntentCatalog`,
`InstalledAppCatalog`, `DeterministicFlowCatalog`, `ExperienceCache`. Nunca
MethodChannel ni PackageManager directo. DIP preservado.

## Ranking (determinista, transparente)

```
score = groundingConfidence·0.50 + expectedSuccess·0.15 + channel·0.15
      + reversible·0.05 + risk + latency + verification·0.05
```

- `expectedSuccess` desconocido → factor excluido (0.0), no se inventa 1.0.
- channel: nanoFlow 1.0 > deterministic 0.9 > androidApi 0.85 > androidIntent 0.8
  > notification 0.7 > … > coordinates 0.1.
- risk penalty: none 0, read −0.01, device −0.03, externalWrite −0.08.
- verification strength: expectedPackage 1.0 > expectedText 0.8 > mustChangeSnapshot 0.5.

## Política de ambigüedad

Margen < 0.10 entre top y segundo, y candidatos materialmente distintos →
`AmbiguousCandidates`. Nunca auto-elegir un target distinto a ciegas. Mismo target
(payload idéntico) con distinta provenance NO es ambiguo: gana el de mayor score.

## Adapter CandidateAction → ToolCall

Solo `args` canónico (sin reintroducir selector/text/key). Valida `candidate.tool`
contra `ToolRegistry` (tool desconocido → `CandidateToolUnknown`). `mustAppear`/
`mustDisappear` (NanoSelector) no se re-serializan en A6 (limitación documentada).

## Deduplicación / aislamiento de fallos

El generador aplana providers → dedup por `CandidateId` (conflicto de payload →
`CandidateConflict` registrado) → `CandidateSet`. Un provider que falla no destruye
el set; se registra `CandidateProviderFailure`.

## Límites de seguridad

- `packageName` SIEMPRE del catálogo (nunca del string del modelo/usuario).
  Test: "abre com.fake.chrome" → NoCandidate.
- Sin `ActionEvidenceSource.llm` (el modelo no hace real una acción).
- Destinos solo allowlisted (SystemDestination), nunca strings crudos de Intent.
- Capability no disponible → provider no emite candidato usable.

## Por qué el planner productivo NO cambia

A6 demuestra el pipeline de forma aislada. La migración del `AutomationCoordinator`
y del `LlmAutomationPlanner` ocurre solo después de que providers + ranker +
ambigüedad + adapter estén probados. Sin cambios a Koog.

## Limitaciones conocidas

- NanoFlow multi-step no produce candidato de acción única (es un flow).
- Notification provider diferido (boundary no tipado).
- Adapter no re-serializa selectores DSL (mustAppear/mustDisappear).

## Relación con A7

A7 añadirá ScreenGraph/SemanticNormalizer como OTRA fuente de candidatos
(Accessibility → semantic objects), sobre un pipeline que ya funciona con facts
deterministas. La arquitectura no cambia: se agrega un provider.
