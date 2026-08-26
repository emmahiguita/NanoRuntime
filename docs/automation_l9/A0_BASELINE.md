# A0 — Baseline NanoAutomation L9

> Auditoría de la implementación actual ANTES de modificar nada.
> Regla fundamental: no atribuir a cambios futuros fallos ya presentes.
> Estado del repo capturado el 2026-08-26.

## 1. Commit / branch de partida

| Campo | Valor |
|---|---|
| Branch | `feature/living-optical-fluid-ui` |
| HEAD real | `5f41f17207a7c4f31ead9b76408344fff53083dc` (`5f41f17`) |
| HEAD auditado en docs L9 | `df75f87` |
| Delta vs. docs L9 | **+7 commits** (la documentación de NanoAutomation_L9_Plan se generó contra un HEAD anterior) |
| Working tree | **SUCIO** — decenas de archivos modificados sin commit en `flutter_app/` y `nanortime-core/`. Ninguno de los archivos del núcleo `engine/execution/` figura como modificado, salvo `automation_engine.dart` y `goal_verifier.dart`. |

Consecuencia: los números de línea y contratos de la documentación L9 pueden diferir ligeramente del código real. Esta auditoría lee el código real, no la documentación.

## 2. Árbol relevante

Monorepo. La automatización vive en dos capas:

```
Nanoai/
├── products/nanoMOBILE/flutter_app/          ← Flutter (Dart)
│   ├── lib/features/automation/              ← módulo completo (51 .dart, ~316 KB)
│   │   ├── application/    automation_engine (facade), automation_coordinator (impl), providers
│   │   ├── domain/         automation_goal, automation_policy, automation_result
│   │   ├── engine/
│   │   │   ├── planning/   automation_planner (LLM), deterministic_catalog, koog
│   │   │   ├── execution/  agent_tool_dispatcher, agent_executor, agent_loop,
│   │   │   │               action_verifier, action_path_router, goal_verifier,
│   │   │   │               stability_gate, nano_flow, tool_registry, agent_result
│   │   │   ├── perception/ nano_snapshot, nano_selector, selector_engine,
│   │   │   │               actionability_engine, perception_mux
│   │   │   ├── memory/     object_memory, experience_cache, nano_recorder
│   │   │   ├── platform/   linux_tool_adapter
│   │   │   └── trust/      instruction_trust
│   │   ├── executors/      notification_executor
│   │   ├── ledger/         action_ledger, automation_trace
│   │   ├── benchmark/      c14_* (benchmark físico)
│   │   └── presentation/   3 pantallas + widgets
│   └── lib/core/services/nano_runtime_api.dart  ← fachada MethodChannel (798 líneas)
└── android/app/src/main/kotlin/dev/nanoai/mobile/
    ├── services/AgentAccessibilityService.kt    ← brazo de ejecución UI
    ├── channels/AgentChannelHandler.kt          ← canal `com.nanoai/agent`
    ├── channels/ChannelHandlers.kt              ← ChannelNames (centralizado)
    └── MainActivity.kt                          ← wiring de canales
```

La separación por capas es adecuada. NO existe un segundo módulo `agent/` paralelo. No crear uno.

## 3. Arquitectura actual

Flujo de ejecución (ya implementado, correcto en su esencia):

```
AutomationEngine.runGoal(goal)                [application, facade fina]
  └─ AutomationCoordinator.execute(goal)      [application, dueño del ciclo]
       │  C11 InstructionTrust.authorizesExecution()   ← goal vacío → noPlan
       ├─ tryDeterministic (ExperienceCache → NanoFlowExecutor)   [sin LLM]
       ├─ DeterministicFlowCatalog.forGoal          [sin LLM]
       ├─ LlmAutomationPlanner.plan (LLM local)     [solo si no hay flujo]
       ├─ _resolveSelectors (ObjectMemory C10 → PerceptionMux C12)
       └─ runPlan / runTool
            └─ AgentToolDispatcher.runPlanGuarded
                 ├─ PolicyEngine.decide  (allow / needsConfirmation / denied)
                 ├─ ActionPathRouter.route (etiqueta ruta, no decide ejecución)
                 └─ _executeTool
                      ├─ NanoAgentExecutor (snapshot → resolve → actionability → settle → tap/setText)
                      ├─ AgentLoop (OBSERVE→RESOLVE→ACT→VERIFY→RECORD, retry transitorio)
                      └─ ActionVerifier (postcondiciones: package/appear/disappear/text/forbidden/mustChangeSnapshot)
            └─ GoalVerifier (task success ≠ plan success)
  └─ _finalizeExecution: completed → satisfied | unverified | notSatisfied
  └─ _recordMemory (SOLO éxitos verificados) + ledger
```

Invariantes de honestidad ya codificadas y testeables:
- `completedUnverified` ≠ `completed` (nunca se declara éxito sin expectativa).
- Un tool permitido que falla en ejecución → `failed`, no `completed` (`_isFailedFeedback`).
- Aprendizaje SOUND: solo memoriza cuando `GoalStatus.satisfied`.
- `dispatchGesture == true` NO es prueba: el `ActionVerifier` toma snapshot fresco tras cada acción.
- Selectores ambiguos (`gap < ambiguityGap`) abortan: no se toca nada.

## 4. Contratos públicos existentes

### 4.1 Domain (vocabulario único del módulo)
- `AutomationResultStatus`: `completed | completedUnverified | paused | denied | noPlan | failed | cancelled`.
- `AutomationResult.isVerifiedSuccess` ≡ `status == completed` (única definición de éxito verificado).
- `AgentAutomationMode`: `manual | assisted | autonomous`.

### 4.2 Ejecución (tool-calling)
- `ToolCall { tool, selector?, text?, key?, expect? }` — contrato ACTUAL. `selector` sobrecarga packageName (`launch_app`) y path (`linux.*`), y `text` sobrecarga contenido a escribir, comando Linux y argumento de tool. Es la principal fuente de acoplamiento para la migración a args tipados (A4).
- `ToolRegistry.builtin` + `ToolDefinition { name, risk, requiresConfirmation, timeout, promptSyntax }`.
- `PolicyVerdict { allow, needsConfirmation, denied }` + `PolicyEngine.decide`.
- `ToolOutcome`, `PlanOutcome { completed, steps, pauseIndex, pauseCall, paths }`.
- `AgentToolProtocol.extractToolCall(s)` — parseo tolerante del JSON del LLM (GGUF sin function-calling fiable).
- `AgentToolPrompt.build(registry)` — solo anuncia tools con `promptSyntax != null`.

### 4.3 Ejecutor / percepción
- `AgentExecutor { snapshot(), resolve(selector), tap(selector), setText(selector, text) }` (interface DIP).
- `NanoSelector` + mini-DSL: `text=`, `text~=`, `text/=`, `desc=`, `id=`, `role=`, `pkg=`, `editable=`, `clickable=`, `near=`.
- `NanoSnapshot { package, nodes }`, `NanoNode { id, type, text, desc, bounds, depth, clickable, editable, scrollable, checked, focusable, focused, visible, enabled }`.
- `Role` (8 valores: button, editText, textView, imageView, checkBox, switch_, listItem, other).

### 4.4 Verificación / memoria
- `ActionExpectation { expectedPackage, mustAppear, mustDisappear, expectedText, forbiddenText, mustChangeSnapshot }`.
- `GoalExpectation { expectedPackage, visibleText, absentText, checkedSelector, expectedChecked }` + `GoalStatus { satisfied, notSatisfied, unverified }`.
- `NanoObjectMemory` (C10): `UiObjectKey { concept, package, appVersion }`, `UiSelectorEvidence`, confianza = éxito/(éxito+fallo), umbral 0.3.
- `ExperienceCache` (C7): flujo verificado por goal, confianza min 0.5.
- `NanoRecorder` (C13): sink append-only, persistencia de objectMemory (schemaVersion 2).

### 4.5 Frontera nativa (MethodChannel)
- `NanoRuntimeChannels`: 10 canales centralizados (`com.nanoai/agent`, `/runtime`, `/exec_bin`, `/pty`, `/device_metrics`, `/navigation`, `/engine`, `/model_storage`, `/notifications`, `/device_permissions`). Espejo Kotlin en `ChannelNames.kt`.
- Canal `com.nanoai/agent` (v1): `getStatus, dumpScreen, dumpSnapshot, findText, tapOnText, tapAt, longPressAt, swipe, inputText, globalAction, launchPackage`.
- `NanoRuntimeApi` expone en Dart TODOS esos métodos. `agentFindText` y `agentTapOnText` marcados `@Deprecated` (peligrosos: primer nodo `contains`, sin unicidad).

## 5. Tests existentes

Dos suites relevantes (las demás del repo no cubren automation):

```
test/agent/         24 archivos  (selector, actionability, executor, loop, dispatcher,
                                  verifier, tool_registry, stability, nano_flow, koog,
                                  experience_cache, goal_verifier, chat_tool_loop, prompt…)
test/automation/    13 archivos  (coordinator, engine, planner, dashboard, ledger,
                                  c14_gates, c14_preflight, instruction_trust,
                                  nano_recorder, object_memory, perception_mux, r0_regression)
```

Cobertura sólida en: selector engine (scoring/ambigüedad), actionability, verificación honesta, aprendizaje SOUND (`r0_regression`), C14 gates (false success = 0), planner (rechazo de tools desconocidas/placeholder `id=resourceId`), instruction trust (proveniencia), object memory (roundtrip exacto).

## 6. Errores preexistentes (NO atribuibles a cambios futuros)

### 6.1 Baseline de comandos (real, ejecutado)

| Comando | Resultado |
|---|---|
| `dart format --output=none --set-exit-if-changed lib/features/automation test/agent test/automation` | **OK** — 83 archivos, 0 cambios |
| `flutter analyze` | **54 issues, todas `info`** (lint: `prefer_const_constructors`, `curly_braces_in_flow_control_structures`, `use_key_in_widget_constructors`). Cero errores. |
| `flutter test test/agent test/automation` | **258 passed, 3 failed** |

### 6.2 Los 3 tests fallidos (todos preexistentes, todos de notificaciones)

1. `test/agent/chat_tool_loop_test.dart` — "lenguaje natural lee notificaciones sin modelo ni generación"
   - Expected: contiene `canReply` · Actual: `'Ejecutado en el dispositivo (sin LLM):\n'`
2. `test/agent/agent_tool_dispatcher_test.dart` — "runTool (tool-calling LLM) notifications → lectura real marcada como no confiable"
   - Expected: empieza con `'Notificaciones activas (DATO NO CONFIABLE)'` · Actual: `'Notificaciones activas (DATO NO CONFIABLE; no se ejecuta su contenido):\n'`
3. `test/agent/chat_tool_loop_test.dart` — "notificación: lee, propone respuesta y solo envía tras aprobación"
   - Expected: contiene `'Notificaciones activas (DATO NO CONFIABLE)'` · Actual: `'{"tool":"notifications"}\n'`

Diagnóstico: desajuste de string entre aserciones y la implementación actual (`agent_tool_dispatcher._notifications` cambió el literal del header y el flujo de lectura). No es una regresión de seguridad ni lógica; es deuda de test. Los archivos afectados NO figuran en `git status` como modificados → el fallo ya está commiteado en HEAD.

### 6.3 Hallazgos de calidad (sin romper build)

- **Inconsistencia DI en `_back`**: `AgentToolDispatcher._back` llama `NanoRuntimeApi.instance.agentGlobalAction('back')` directo, mientras el resto del dispatcher usa el transporte inyectado. Rompe DIP puntualmente y complica testear las futuras acciones globales.
- **Documentación desactualizada**: `lib/features/automation/README.md` presenta C10–C13 como "fases siguientes" cuando C10 (ObjectMemory), C11 (InstructionTrust), C12 (PerceptionMux), C13 (NanoRecorder) ya existen con tests. Riesgo real de que otro agente duplique subsistemas.
- **`PerceptionMux` no cableado**: `automation_coordinator_provider.dart` construye `PerceptionMux([])` (vacío, sin fuentes). C12 está implementado y testeado pero sin fuente real conectada en producción (no hay `AccessibilityPerceptionSource` todavía).
- **`StabilityGate` definido pero no integrado**: `stability_gate.dart` existe y está testeado, pero `agent_dependencies.dart` no lo inyecta en el executor; el executor usa su propio `StabilityChecker` inline. Duplicación conceptual menor (gate de árbol completo vs. checker por-nodo).

## 7. Riesgos de migración (a vigilar en A1+)

1. Cambiar `ToolCall` de golpe rompe planner + dispatcher + tests + ledger + benchmark (C14). → A4 debe migrar con adapters y compat temporal.
2. `launch_app` anunciada al LLM autónomo sin catálogo de packages → superficie de "packageName inventado" (ver §8). El `regex` de Kotlin solo valida sintaxis, no existencia.
3. Introducir visión antes de cerrar IntentFirewall/PrivilegeBroker amplía la superficie de prompt-injection indirecta (C11 cubre la base textual; falta la parte tipada).
4. AppGraph sin screenSignature/versionado aprende rutas frágiles (ObjectMemory ya tiene `package`/`appVersion` en `UiObjectKey`, bien; falta poblarlos con datos reales del PackageManager).
5. `dispatchGesture == true` = "gesture accepted", no "resultado logrado" — ya cubierto por ActionVerifier; NO relajar en las nuevas acciones (swipe/scroll/long-press) que por defecto no cambian snapshot (scroll sí).
6. Package visibility de Android: no asumir `QUERY_ALL_PACKAGES`; el AppGraph deberá usar `<queries>`/intents.

## 8. Puntos de extensión (dónde encaja L9 sin romper)

- `AgentExecutor` (interface) → agregar `home/recents/openShade/quickSettings/swipe/scroll/longPress/drag` como métodos nuevos NO rompe Liskov (ampliación de interfaz con default o implementación en `NanoAgentExecutor`).
- `ToolRegistry.builtin` → fuente de verdad extensible; A1 añade `ToolDefinition`s nuevos sin tocar el `PolicyEngine`.
- `AgentToolDispatcher._executeTool` → `switch(call.tool)` listo para nuevos cases.
- `ActionPathRouter` → ya tiene el enum `ExecutionPath` con `ocr/vision/coordinates` declarados (futuro); A1 añade `androidIntent` para las acciones globales.
- `ActionExpectation`/`GoalExpectation` → listos para predicates tipados (A11); hoy son campos opcionales.
- `PerceptionMux`/`PerceptionSource` → contrato ya existente para enchufar OCR/Vision/Accessibility como fuentes (A8–A10).
- `ChannelNames.kt`/`NanoRuntimeChannels` → centralizados; A2 añade `com.nanoai/system` SOLO si hay frontera nativa real (SystemInventory).

## 9. Brecha A1 — capacidades nativas NO expuestas como tools

Comparación capa por capa: nativo (`AgentAccessibilityService`) → transporte (`NanoRuntimeApi`) → vocabulario (`ToolRegistry.builtin`) → ejecución (`AgentToolDispatcher`).

| Capacidad nativa (Kotlin) | Transporte Dart | Tool en registry | Case en dispatcher | Verdict |
|---|---|---|---|---|
| `tapAt` | `agentTapAt` | `tap` | `_tap` | **OK** |
| `inputText` | `agentInputText` | `write` | `_write` | **OK** (sin postcondición de campo verificada en todos los casos) |
| `globalAction back` | `agentGlobalAction` | `back` | `_back` | **OK** |
| `globalAction home` | `agentGlobalAction` | ✗ | ✗ | **BRECHA** |
| `globalAction recents` | `agentGlobalAction` | ✗ | ✗ | **BRECHA** |
| `globalAction notifications` (abrir shade) | `agentGlobalAction` | ✗ (la tool `notifications` = LEER lista) | ✗ | **BRECHA** |
| `globalAction quick_settings` | `agentGlobalAction` | ✗ | ✗ | **BRECHA** |
| `swipe` | `agentSwipe` | ✗ | ✗ | **BRECHA** |
| `longPressAt` | `agentLongPressAt` | ✗ | ✗ | **BRECHA** |
| `scroll` (derivado de swipe) | — | ✗ | ✗ | **BRECHA** |
| `drag` (strokes continuados) | — (nativo solo swipe recto) | ✗ | ✗ | **BRECHA** (también falta en nativo) |
| `launchPackage` | `agentLaunchPackage` | `launch_app` (sin `promptSyntax`) | `_launchPackage` | **PARCIAL** (sin grounding de packages) |
| `dumpSnapshot`/`dumpScreen` | `agentDumpSnapshot`/`agentDumpScreen` | `screen`/`resolve` | `_describeScreen`/`_resolve` | **OK** |

### 9.1 La inconsistencia crítica de `launch_app`

- `AgentToolPrompt.build` (chat tool-calling) filtra `promptSyntax != null` → **NO** anuncia `launch_app` al LLM del chat. Correcto.
- `LlmAutomationPlanner._knownTools` = `ToolRegistry.builtin.all.map(name)` → **SÍ** anuncia `launch_app` al planner autónomo, porque incluye el nombre aunque `promptSyntax` sea null. El planner lista `launch_app` en el prompt sin un catálogo de packages válidos → el modelo puede emitir `{"tool":"launch_app","selector":"com.fabricado.app"}`. El dispatcher lo pasa directo (Kotlin valida solo el regex `[a-zA-Z0-9._]+`). Resultado honesto (`[launchFailed]`) pero superficie de "package inventado" que el prompt maestro prohíbe.

### 9.2 Brecha de alto nivel (más allá de tools)

- `AgentExecutor` (interface) solo expone `snapshot/resolve/tap/setText`. Las acciones de gesto (swipe/scroll/long-press/drag) y las global actions (home/recents/shade/quick-settings) NO tienen primitiva de alto nivel con su cadena resolve→actionability→stability→verify. `_back` es la única global action y se implementa fuera del executor, con singleton directo.

## 10. Propuesta de patch mínimo A1 (SIN modificar aún — decisión pendiente del usuario)

Objetivo: cerrar la brecha de Device Actions V1 tipadas SIN tocar el núcleo de orquestación. A1 es aditivo.

### 10.1 Archivos que se tocarían

| Archivo | Cambio |
|---|---|
| `engine/execution/agent_executor.dart` | Añadir a la interface `AgentExecutor` y a `NanoAgentExecutor` los métodos `globalAction(...)`, `swipe(...)`, `scroll(...)`, `longPress(...)`. Usar el transporte inyectado `_api` (NO singleton). |
| `engine/execution/tool_registry.dart` | Añadir `ToolDefinition`s: `home`, `recents`, `open_notifications`, `open_quick_settings`, `swipe`, `scroll`, `long_press` (riesgo `device`; `promptSyntax` explícito para swipe/scroll con argumentos tipados). |
| `engine/execution/agent_tool_dispatcher.dart` | Añadir cases en `_executeTool` + verbos `@` equivalentes + postcondiciones por defecto (`mustChangeSnapshot` para home/recents/shade; snapshot-cambio para scroll). Mover `_back` al transporte inyectado (corrige 6.3). |
| `engine/execution/action_path_router.dart` | Clasificar las nuevas global actions y gestos como `accessibility` (y `androidIntent` cuando aplique). |
| `engine/execution/agent_loop.dart` | Ampliar `AgentAction` con las nuevas acciones y sus ramas en `_runStep` (si se quiere verificación por-paso de gestos). |

### 10.2 Contratos nuevos (aditivos)

- `enum GlobalActionKind { back, home, recents, notificationsShade, quickSettings }` (o reutilizar el string ya validado en Kotlin, pero tipado en Dart).
- Parámetros tipados para gestos: `SwipeSpec`, `ScrollSpec` (dirección), `LongPressSpec` — nunca coordenadas crudas del LLM sin selector/evidencia.

### 10.3 Tests que se crearían

- `test/agent/global_action_test.dart`: home/recents/shade/quick-settings mapean a `agentGlobalAction` correcto y verifican `mustChangeSnapshot`.
- `test/agent/gesture_tools_test.dart`: swipe/scroll/long-press parsean specs tipados; argumentos inválidos → `[tool]` (no excepción).
- Regresión: `launch_app` sin catálogo NO se anuncia al planner autónomo (filtrar `_knownTools` por `promptSyntax != null` o por una nueva whitelist de packages).

### 10.4 Riesgos de compatibilidad

- Ampliar `AgentExecutor` (interface) es breaking para cualquier fake de test que la implemente → revisar `test/agent/fixtures.dart` y los fakes existentes; añadir default methods o actualizar fakes.
- `ToolCall.selector` seguirá sobrecargando argumentos en A1 (la migración tipada es A4). NO migrar `ToolCall` todavía.
- Nuevos tools de gesto con `risk: device` y modo `assisted` → pedirán confirmación si `AgentAutomationPolicy.requiresConfirmation` los lista; ajustar política solo si se quiere `home`/`back` sin confirmación (hoy `back` está listado en assisted).

### 10.5 Dependency graph afectado

```
ToolRegistry.builtin (nuevos ToolDefinition)
        ▲
AgentToolDispatcher ──► AgentExecutor (interface ampliada)
        │                    ▲
        └──► ActionPathRouter (nueva clasificación)
        │
        └──► AgentLoop (nuevas AgentAction, solo si verificación por-paso)
AutomationCoordinator (sin cambios — consume dispatcher igual)
```

El núcleo `AutomationCoordinator → PolicyEngine → GoalVerifier → ObjectMemory` **no se toca**.

---

*Próximo paso: validar con el usuario el alcance de A1 antes de escribir código.*
