# Módulo de Automatización

## Capacidad REAL vs. pendiente (milestone)

> **NanoAutomation puede ejecutar objetivos conocidos SIN LLM, planear objetivos
> desconocidos mediante un modelo local, gobernar las acciones, verificar
> resultados y convertir ejecuciones verificadas en flujos deterministas
> reutilizables. Para objetivos nuevos, la principal limitación actual es el
> grounding/identidad de objetos UI, que se aborda en C10.**

### Lo que SÍ hace hoy (probado)
- `runGoal(goal)` ejecuta acciones reales (tap/write/back/app) por accesibilidad.
- **Sin LLM**: objetivos del catálogo determinista (Bluetooth, Wi-Fi, Ajustes,
  Chrome, volver) → ejecución real + verificación + aprendizaje.
- **Gobernanza** en 3 niveles (manual/asistido/autónomo).
- **Verificación** honesta (GoalVerifier); sin expectativa no se declara éxito.
- **Aprende SOUND**: memoriza solo flujos cuyo objetivo se verificó satisfecho.
- **Ledger** de ejecuciones reales + **benchmark C14-A** del planner.

### Lo que NO hace aún (limitación real)
- **Planner de calidad para objetivos desconocidos**: el modelo local (Qwen 1.5B)
  puede producir selectores pobres/placeholder (`id=resourceId`) → esos planes
  fallan en ejecución (reportado `failed`, nunca éxito falso).
- **Ejecución completa en device** requiere accesibilidad manual activada
  (Android la blquea vía adb).
- **Grounding/identidad de objetivos UI** → **C10**.

### Fases
- **C10 NanoObjectMemory**: memoria + identidad verificable de elementos UI
  (selectores reales por package/app, confianza, recuperación).
- C11 InstructionTrust · C12 PerceptionMux · C13 NanoRecorder · C14-B (100+).

---
## Qué hace

> **Dado un objetivo (goal) en lenguaje natural, lo convierte en acciones
> verificadas sobre Android/Linux, y aprende de lo que funciona.**

No es "automatización del chat": es un **motor autónomo reutilizable** por
chat, notificaciones, voz, eventos y tareas programadas.

## Cómo funciona (el pipeline)

```
            SOURCES (chat / notif / voz / evento)
                         │
                  AutomationEngine.runGoal(goal)
                         │
        ┌────────────────┴────────────────┐
        ▼                                 ▼
  ¿flujo verificado            Planner LLM local
  en Memory?            →      (misión → plan de tools)
  │  sí: determinista            │
  ▼                              ▼
        ActionPathRouter (¿Android / Linux?)
                         │
                  Policy (gobernanza)
                         │
                  Executor (ejecuta, audita)
                         │
                  Verifier (¿objetivo logrado?)
                         │
                  Memory (aprende SOLO éxitos verificados)
                         │
                  Ledger (traza real de qué hizo)
                         ▼
               AutomationResult honesto
```

**Honestidad ante todo**: un plan que "completó" a nivel de pasos pero NO
logró el objetivo NO se memoriza (aprendizaje sound). Un tool permitido que
falló en ejecución se reporta `failed`, no `completed`.

## API pública

```dart
final engine = ref.read(automationEngineProvider);

AutomationResult r = await engine.runGoal(AutomationGoal(text: 'abre Bluetooth'));
r.status // completed | completedUnverified | paused | denied | noPlan | failed | cancelled
r.reason // por qué (nunca inventa éxito)

engine.trace()            // qué hizo realmente (ledger)
engine.traceOf('abre Bluetooth')
```

## Layout

```
lib/features/automation/
├── application/
│   ├── automation_engine.dart            ← API pública (runGoal / trace)
│   ├── automation_coordinator.dart       ← impl (orquesta el ciclo)
│   └── *_provider.dart                    ← DI del módulo
├── domain/
│   ├── automation_goal.dart               ← el objetivo + opciones
│   ├── automation_policy.dart             ← nivel de autonomía (manual/asistido/autónomo)
│   └── automation_result.dart             ← el resultado honesto
├── engine/
│   ├── planning/                           genera planes (planner, koog)
│   ├── execution/                          ejecuta bajo gobernanza (loop/dispatcher/...)
│   ├── perception/                         lee pantalla (selector/snapshot/...)
│   ├── memory/                             aprende (experience_cache)
│   ├── platform/                           adaptador Linux
│   └── agent_dependencies.dart             DI raíz del motor
├── executors/                              notification_executor
├── ledger/                                 trazas reales (auditoría)
├── benchmark/                              C14-A (benchmark físico del planner)
└── presentation/                           pantalla /automation + consola
```

## Precondiciones para ejecutar en dispositivo

`C14Preflight` verifica: runtime vivo, modelo cargado (GGUF), accesibilidad
ON, coordinator listo, política configurada, pantalla desbloqueada. **Linux no
se requiera** — se provisiona on-demand (perfil `automationBenchmark` lo salta).

## Fases siguientes (plan maestro)

- **C10 NanoObjectMemory**: aprender selectores REALES de pantalla (el Qwen
  local produce `id=resourceId` placeholder — el cuello de botella actual).
- **C11 InstructionTrust**: separar instrucción del usuario de contenido
  observado (antes de abrir visión/web profunda).
- **C12 PerceptionMux**, **C13 NanoRecorder**.
