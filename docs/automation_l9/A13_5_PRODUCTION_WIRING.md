# A13.5 — Production Candidate-First + Governance Wiring

> Estado: WIRED (coordinator productivo) · DEVICE-VERIFIED: N/A (puro Dart).

## Viejo flujo

```
AutomationGoal → cache(NanoFlow) → AppLaunchResolver → DeterministicCatalog → LlmAutomationPlanner → dispatcher
```

## Nuevo flujo

```
AutomationGoal
→ InstructionTrust (C11)
→ cache/NanoFlow (tryDeterministic)
→ CandidateFirstPlanner (generator → selection → governance → adapter)
     ├ Resolved   → ToolCall (0 LLM)
     ├ Governed   → AutomationResult (denied/paused/noPlan)
     └ NoCandidate → legacy fallback (AppLaunchResolver → catalog → LLM planner)
→ dispatcher → ActionVerifier → GoalVerifier → memoria/ledger
```

## Orquestación

`AutomationCoordinator` sigue siendo la ÚNICA fachada productiva. `NanoAgentOrchestrator`
(A13) coordina el pipeline; A13.5 cablea el `CandidateFirstPlanner` al coordinator
como puerto ANTES del fallback legacy. No hay segundo engine.

## Skills

Los skills (A13) entran como fuentes de candidatos vía los providers A6 (no ejecutan
directo). A13.5 cablea los providers, no los skills directamente (los skills son
thin wrappers de los providers).

## Candidate-First

`CandidateFirstPlanner`: generator (deterministic/app/intent/nanoFlow) → selection
(ranker determinista, Koog solo ambigüedad) → governance (firewall/critic/broker)
→ adapter → ToolCall. Resuelto → expectation de GOAL derivada de la postcondición
de la acción.

## Koog

Solo en ambigüedad, candidateId-only, ≤1 LLM. Desconocido → rechazado. Sin fallback
a ToolCall arbitrario.

## Governance

Obligatorio para cada CandidateAction antes de ToolCall. Resultados honestos:
denied → `denied`; confirmation → `paused`; moreEvidence → `noPlan`.

## Privilege broker

A11 broker (publicAndroid/notification/accessibility/nanoLinux). Sin Shizuku/ADB/
root. Prueba la integración del broker ANTES de A14.

## Policy / ejecución / verificación

PolicyEngine/AutomationPolicy siguen autoritativas para modo. Ejecución vía
dispatcher existente (strangler boundary). Verificación: solo GoalVerifier concluye
satisfacción; candidate seleccionado ≠ éxito.

## Memoria / ledger

Solo resultado verificado entrena memoria positiva (SOUND). Koog/ranker no entrenan
memoria. Ledger sin cambios de formato (A13.5 no lo extiende aún).

## Fallback legacy (temporal)

`NoCandidate` → legacy AppLaunchResolver/catálogo/planner LLM. El planner LLM
permanece como fallback; el objetivo es `legacyFallbackRate → 0` cuando ScreenGraph
candidate providers y Skills maduren. El A11 IntentSpec NO gobierna ToolCalls
legacy arbitrarios (gap documentado).

## Limitaciones

- Graph de intents estático (`_intentGraph`) para el SystemIntentCandidateProvider;
  el SystemGraph REAL (async, con accessibility/notification/Linux) se cablea en
  follow-up.
- Sin ScreenGraphCandidateProvider todavía.
- Sin métrica formal de legacyFallbackRate (se añadirá en C14).

## Plan de eliminación del fallback legacy

Cuando el pipeline Candidate-First cubra todos los goals conocidos y los providers
de ScreenGraph/Skills maduren, el `LlmAutomationPlanner` pasará de fallback a
removible. Sin fecha hardcoded; gobernado por evidencia de tests.
