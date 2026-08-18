# Battery de recovery — OPPO CPH2557 (P4 watchdog)

Evidencia de la máquina de estados del watchdog (`EngineSupervisor`) cableada
al cliente Flutter, ejecutada en hardware real.

## Setup

```text
APK release con binario nanortime static-stdcxx (bootstrap fixed)
+ parche verifiedState async + process_alive autoritativo
+ /debug/kill (crash simulado vía exit(1))
+ escalada stall→restart (5 ticks sin progreso)
```

## Resultados

| Prueba | Resultado | Evidencia |
|--------|-----------|-----------|
| A kill en idle | ✅ | PID 8822 → 8937, restart automático, health OK |
| B kill decode + stall | ✅ | PID 13460 → 13658, escalada stall→restart |
| F kill + background + foreground | ⚠️ | no recovery: el timer de health se pausa en background |

## Diagnóstico de F (bug P6, no P4)

Al enviar la app a background (`KEYCODE_HOME`), el `Timer.periodic` del health
check de Dart se pausa (Android suspende timers en background). El server muere
durante el background y, al volver a foreground, el watchdog no re-detecta la
muerte a tiempo. Es un problema de **Android lifecycle** (P6): el watchdog debe
reanudar el health check al volver a foreground y detectar la muerte del server
inmediatamente (p. ej. vía `WidgetsBindingObserver` / `AppLifecycleState`).

## Lo que cierra

```text
P4 Recovery: A + B verificados (proceso muerto + stalled). C–F pendiente.
P6 Android:  F reveló el gap del timer en background.
```

## Pendiente para cerrar la batería

```text
C  health transitorio   → endpoint health-flaky
D  modelo falla         → manifest inválido → fallback 1.5B
E  restart budget       → restarts fallidos → SafeMode
F  background           → reanudar health check en foreground (WidgetsBindingObserver)
G–L memoria             → forzar presión de memoria
```
