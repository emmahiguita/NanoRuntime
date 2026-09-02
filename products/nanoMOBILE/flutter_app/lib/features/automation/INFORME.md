# INFORME del módulo de Automatización

> Documento de referencia: componentes de UI (pantalla, secciones, botones,
> controles) + lógica (flujo, clases, pipeline) del módulo
> `features/automation/`. Complementa el README (visión) con el detalle de
> implementación.

## 1. ¿Qué es el módulo?

Convierte un **objetivo (goal)** en lenguaje natural en **acciones verificadas
sobre Android/Linux**, y **aprende de lo que funciona**. Motor autónomo
reutilizable (chat, notificaciones, voz, eventos, scheduler).

Composición por capas:
```
application/  (API pública + coordinador)     ←  "qué hace"
domain/       (goal, policy, result)          ←  contratos
engine/       (planning/execution/perception/memory/platform)  ← motor
executors/    (notification_executor)         ← casos de uso
ledger/       (trazas reales)                 ← auditoría
benchmark/    (C14-A)                          ← medición física
presentation/ (pantalla + consolas)           ← UI
```

---

## 2. Capa de presentación (UI)

### 2.1 `presentation/screens/automation_screen.dart` — Pantalla "Automatización"

Pantalla dedicada (NO vive en Ajustes). Es la ruta `/automation`.

**Composición**: `NanoAmbientBackground` (fondo) → `NanoScreenShell` (shell)
→ Layout responsive (columna única <900; dos columnas ≥900).

| Componente | Qué es | Acción |
|-----------|--------|--------|
| **ChoiceGroup "Nivel de automatización"** | Selector de autonomía | `setAgentAutomationMode(mode)` |
| — opciones | `manual` / `assisted` / `autonomous` | cambia `AutomationPolicy` |
| **AgentConsoleSection** | Consola del agente de UI | (ver 2.2) |
| **NotificationAutomationSection** | Auto. de notificaciones | (ver 2.3) |
| **C14DebugBenchmarkSection** (solo kDebugMode) | Benchmark físico C14-A | (ver 2.4) |

### 2.2 `presentation/agent_console_section.dart` — Consola del agente de UI

Playground MANUAL del motor (snapshot/resolve/tap/write/gestos) — útil para
debuggear selectores sin pasar por el LLM. Estado: `_busy` (bloquea botones
mientras un op corre).

| Control | Tipo | Handler | Qué hace |
|---------|------|---------|----------|
| **Texto "selector/expresión"** | `TextField` (`_selectorController`) | — | entrada del selector DSL (`text=...`, `id=...`, `text~=...`) |
| **Botón Probe** (👁 visibilidad) | `FilledButton.icon` | `_probe()` | snapshot de la pantalla (nodo raíz) |
| **Botón "Resolver"** (🔍) | `OutlinedButton.icon` | `_resolve()` | resuelve selector → coordenadas |
| **Botón "Tap seguro"** (👆) | `FilledButton.icon` | `_tapSafe()` | tap por coordenadas (con guardas) |
| **Texto "escribir"** | `TextField` (`_setTextController`) | — | texto a escribir |
| **Botón "Escribir"** (⌨️) | `OutlinedButton.icon` | `_setText()` | setText en campo enfocado |
| **Botón "Volver"** | gesto | `_gesture('back')` | retrocede |
| **Botón "Lanzar"** | gesto | `_gesture('launch')` | lanza un intent |
| **Botón "Swipe"** | gesto | `_gesture('swipe')` | gesto swipe |

Todos: `onPressed: _busy ? null : <handler>` (deshabilitados en curso).

### 2.3 `presentation/notification_automation_section.dart` — Auto. de notificaciones

Lee notificaciones, genera borrador local (LLM) y responde CONFIRMADO.

| Control | Tipo | Handler | Qué hace |
|---------|------|---------|----------|
| **"Conceder acceso en Android"** | `FilledButton.icon` | `_requestAccess()` | abre Ajustes de permisos de notificaciones; diálogo Aceptar/Rechazar |
| **Icono refresh** | `IconButton` | `_refresh()` | recarga la lista de notificaciones |
| **Texto respuesta** | `TextField` | — | borrador/entrada de respuesta |
| **Botón confirmar/enviar** | `FilledButton.icon` | `_confirmReply()` | muestra diálogo **"Confirmar respuesta"** → "Cancelar" (pop false) / "Enviar" (pop true) → envía + refresh |

Usa `NotificationExecutor` (executors/notification_executor.dart) —
genérico local + envío confirmado; el texto de la notificación se trata como
dato no fiable (nunca instrucción).

### 2.4 `presentation/widgets/c14_debug_benchmark_section.dart` — Benchmark (solo kDebugMode)

| Control | Tipo | Handler | Qué hace |
|---------|------|---------|----------|
| **Preflight status** | chips OK/FAIL | — | runtime/modelo/accesibilidad/coordinator/política/pantalla |
| **"RUN C14-A"** | `FilledButton.icon` | `_run()` | `runC14Benchmark(container)` → ejecuta la suite |
| **Progress** (n/10, goal, estado) | texto | — | en vivo durante el run |
| **"Copiar reporte"** | `OutlinedButton.icon` | `_copy(_reportText())` | copia el reporte de gates |
| **"Exportar JSON"** | `OutlinedButton.icon` | `_exportJson()` | dialog con JSON (contexto + ejecuciones) + copiar |

---

## 3. Capa de aplicación (lógica de alto nivel)

### 3.1 `application/automation_engine.dart` — API PÚBLICA (facade)

```dart
AutomationResult runGoal(AutomationGoal goal)   // objetivo → acciones verificadas
List<AutomationTrace> trace()                    // qué hizo realmente
List<AutomationTrace> traceOf(String goal)       // auditar un flujo
```
Facade fina sobre `AutomationCoordinator`. Quien entra ve `runGoal` (+ trace);
la maquinaria queda detrás.

### 3.2 `application/automation_coordinator.dart` — la implementación (orquesta el ciclo)

Métodos públicos (los primitivos los usa el chat; `execute` es la entrada):
- `execute(AutomationGoal goal, {plan, options}) → AutomationResult` — el ciclo completo.
- `tryDeterministic(goal, {expectation})` — cache → flow determinista (C7→C8).
- `runPlan(plan, {confirmed, recordGoal, expectation})` — plan multi-paso (aprende SOUND).
- `runTool(call, {confirmed})` — tool única.
- `requiresConfirmation(tool)` / `confirmationDescription(tool)` — política.
- `runCommand(cmd)` / `reset()` — `@` comandos + ciclo de ronda.
- `withSink(...)` — benchmark.

**Pipeline interno de `execute(goal)`**:
```
goal
  ├─ ¿flujo verificado en Memory?  → SÍ → determinista (resultado)
  └─ NO → plannner LLM local (cache el plan de tools)
        → plan multi-paso (runPlan) o tool única (runTool)
        → under gobernanza (Policy) → ejecuta → verifica
        → aprende SÓLO si el objetivo se verificó satisfecho (sound)
        → traza al ledger → AutomationResult honesto
```

**Aprendizaje SOUND** (`_learn`): solo memoriza (`recordSuccess`) si
`GoalVerifier` devuelve `satisfied`; un plan que "completó" por pasos pero no
logró el objetivo → `recordFailure` (no se memoriza el plan malo).

**Honestidad en resultados** (`_statusFrom*`):
- `allow` + feedback de fallo (`[notFound]`, etc.) → `failed` (no false success).
- pausa (`pauseIndex != null`) → `paused` (no degrada cache).
- `satisfied` → `completed`; sin expectation y plan completo → `completedUnverified`.

### 3.3 `domain/` — contratos

| Archivo | Contrato |
|---------|----------|
| `automation_goal.dart` | `AutomationGoal` (text + expectation), `AutomationOptions` (executionId, confirmed) |
| `automation_policy.dart` | `AgentAutomationMode` (manual/asistido/autónomo) + `AutomationPolicy` (¿pide confirmación? por tool) |
| `automation_result.dart` | `AutomationResultStatus` (completed/completedUnverified/paused/denied/noPlan/failed/cancelled) + `AutomationResult` |

---

## 4. Capa de motor (`engine/` por rol)

| Carpeta | Archivos | Rol |
|---------|----------|-----|
| **planning/** | `automation_planner` (DIP→LLM, valida salida), `koog` (orquestador) | genera el plan de tools |
| **execution/** | `agent_loop`, `agent_tool_dispatcher`, `agent_executor`, `action_verifier`, `action_path_router`, `stability_gate`, `nano_flow`, `tool_registry`, `goal_verifier`, `agent_result` | ejecuta bajo gobernanza |
| **perception/** | `nano_selector`, `nano_snapshot`, `selector_engine`, `actionability_engine` | lee la pantalla |
| **memory/** | `experience_cache` | aprende (flujos verificados) |
| **platform/** | `linux_tool_adapter` | adaptador Linux (DIP `LinuxCommandRunner`) |
| raíz | `agent_dependencies.dart` | DI del motor (composition root) |

**Planner (`automation_planner`)**: prompt → `LLMEngineClient.generate` →
`AgentToolProtocol.extractToolCalls` → VALIDA (rechaza tool desconocida,
`write ""`, `back` con selector, `screen` con selector, placeholder
`id=resourceId`). La salida del modelo es dato NO fiable.

---

## 5. Ledger (auditoría) y Benchmark

| Capa | Qué |
|------|-----|
| **ledger/** | `AutomationTrace` (estado honesto + duración), `ActionLedger` (bounded), provider compartido. Qué hizo REALMENTE. |
| **benchmark/** | C14-A: `C14Metrics` (ejecución + gates ≥90% válidos / ≥80% éxito / 0 unknown / 0 false-success), `C14Preflight` (aborta con código si falta dependencia), `C14Context` (reproducible: commit/modelo/perfil), `C14Benchmark` (corre suite), `C14Runner` (único punto, checa endpoint real del motor). |

---

## 6. Flujo de datos resumido

```
AutomationGoal → AutomationEngine.runGoal
  → ¿cache hit? → determinista (Memory)
  → NO → Planner (LLM local, valida) → plan
  → Policy (¿confirma?) → Executor (ejecuta, audita)
  → Verifier (¿objetivo?) → Memory (aprende SOLO satisfecho) → Ledger (traza)
  → AutomationResult honesto (nunca inventa éxito)
```

## 7. Precondiciones / medición (on-device)

- Preflight C14-A requiere: runtime vivo, modelo GGUF cargado, ACCESIBILIDAD
  activada (manual), coordinator listo, política configurada, pantalla activa.
  **Linux no requerido** (perfil `automationBenchmark` salta su provisioning).
- C14-A mide planner→Android→verificación; Linux se certifica aparte (C14-L).
