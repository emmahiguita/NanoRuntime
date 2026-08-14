# Diseño: Funcionalidad faltante de orquestación (agente, degradación, RAM, honestidad)

Fecha: 2026-08-13
Estado: aprobado por el usuario (4 secciones)
Contexto: veredicto de auditoría de orquestación nanoMOBILE — 4 frentes de funcionalidad faltante, prioridad: agente → degradación → RAM → honestidad.

Filosofía NanoRuntime (define severidad y valor):
1. Graceful degradation — "mejor lento y vivo que rápido y muerto".
2. Cero configuración / máxima adaptación.
3. Democratización hardware-agnóstica (~$150).
4. Honestidad radical sobre límites.

---

## Sección 1: Agente — gap real verificado (corrección de auditoría)

**Corrección al veredicto (verificada en código 2026-08-13):** la cadena snapshot→resolve→actionability→gesto SÍ está cableada. `AgentToolDispatcher` (`lib/core/agent/agent_tool_dispatcher.dart`) ya implementa: parseo tolerante de JSON de herramienta (`AgentToolProtocol.extractToolCall`), ejecución vía `NanoAgentExecutor`, comandos `@` deterministas, y el bucle tool-calling está en `chat_provider.dart` `_generateRound` (líneas 404-423) con `_maxToolRounds=2`, `_toolTurnSuffix` que inyecta el resultado al trace, y trace honesto visible en el chat. Hay 7 tests de integración (`test/agent/chat_tool_loop_test.dart`). El hallazgo de auditoría "nunca se cablea / clase inexistente" era falso.

**Gap real (lo único que falta):**
1. `AgentToolDispatcher.runTool` solo expone `screen/tap/write/back`. El canal y `NanoRuntimeApi` ya soportan `swipe`, `globalAction`, `launchPackage` (`nano_runtime_api.dart:546,580,593`) pero el modelo no puede llamarlas — el prompt de sistema tampoco las anuncia.
2. `_maxToolRounds=2` (ya testeado) se mantiene en 2 — el código real manda sobre el spec original que pedía 3.

**Componentes:**
1. `agent_tool_dispatcher.dart`: añadir al switch de `runTool`: `swipe` (con `swipeFrom/swipeTo` o selector resuelto + dirección), `global` (globalAction: back/home/recents), `launch` (launchPackage con packageName).
2. `chat_provider.dart` `_systemPrompt`: anunciar las 3 herramientas nuevas con sintaxis exacta.
3. Tests: extender `test/agent/agent_tool_dispatcher_test.dart` y `chat_tool_loop_test.dart` (una herramienta nueva llamada por el LLM → se ejecuta y re-genera).

**Flujo de datos:** sin cambios — `modelo → JSON {"tool":...} → extractToolCall → runTool → resultado al trace`.

---

## Sección 2: Degradación de contexto automática por RAM

**Decisión:** escalón elegido por RAM libre real + longitud de historia. Sin switches manuales (pilar 2). Modo Eco automático.

**Componentes:**

1. `lib/core/agent/context_budget.dart` (puro, testable):
   - Niveles: `[8192, 4096, 2048, 1024, 512]`.
   - Entradas: `ramLibreBytes` (de `DeviceMetricsProvider.availMem`, ya medido real en `DeviceMetricsProvider.kt:18-19`) y longitud de historia (estimación tokens ≈ chars/4 — estimación declarada, honesta).
   - Umbrales: `<512MB→512`, `<1GB→1024`, `<2GB→2048`, `<4GB→4096`, si no `8192`.
   - Historia estimada >80% del presupuesto → bajar un escalón.
   - Histéresis: subir escalón solo si RAM libre supera umbral +25% (evita oscilación con GC).
2. Aplicación en `chat_provider.dart`: reemplaza `_maxHistoryMessages=40` (líneas 37, 218-220, 237-238) por recorte por presupuesto de tokens estimados. Conservar siempre mensaje de sistema y último del usuario; nunca cortar a 0.
3. `n_ctx` al motor según escalón si el backend lo soporta; si no, solo recorte de historia. Sin falsas promesas al backend.
4. Honestidad: chip discreto en UI de chat con escalón activo ("Eco 512" etc.) — el usuario entiende por qué respuestas más cortas.

**Tests:** elección de escalón por umbrales; histéresis (no oscila); estimación tokens; recorte de historia conserva system+último usuario.

---

## Sección 3: Puerta de RAM al cargar modelo

**Decisión:** bloquear con motivo. No arrancar motor si el modelo no cabe — evita OOM del OS que mata sin aviso (viola pilares 1 y 4).

**Componentes:**

1. Verificación en `useDetected` y `loadModel` (`lib/features/models/application/models_notifier.dart:149-161, 242-270`): antes de kill+respawn del motor, medir `availMem` real.
2. Regla: `model.ramGb > ramLibreGb + 0.25` (margen 256MB para sistema) → no arranca. Nuevo estado tipado `ModelLoadStatus.insufficientRam` con motivo en español: "El modelo pide ~X GB y quedan Y GB libres. Libera RAM o usa un modelo más pequeño."
3. UI (`models_screen.dart`): el aviso actual (línea 190-192) pasa de cosmético a puerta real; muestra el motivo exacto devuelto.
4. Degradación: si la medición falla (canal métricas muerto) → no bloquear; arrancar con `ramUnknown` + advertencia en log. Bloquear sin dato viola pilar 1.

**Tests:** comparador con margen; estado tipado `insufficientRam`; camino `ramUnknown`.

---

## Sección 4: Honestidad UI y nativa

**Decisión:** tres fixes puntuales de pilar 4.

1. **Barra de progreso** (`lib/features/desktop/presentation/screens/desktop_launch_screen.dart:145-159`): eliminar porcentajes inventados 60/75/90/95. Barra indeterminada por etapa real de `stage` (`idle/starting/xvnc/rfb/wm/ready`) con texto real. El `stage` ya viene honesto de `DesktopSessionManager`. Cumple el comentario existente "en vez de porcentajes inventados".
2. **`TERMUX_APK_RELEASE`** (`lib/features/terminal/terminal_core.dart:283`): `'F_DROID'` → `'nanoMOBILE'`. Scripts que comparan `==F_DROID` dejan de matchear — correcto, no somos F-Droid.
3. **Banner "NanoTerminal rootfs ARM64"** (`terminal_core.dart:211`): imprimir solo si rootfs existe de verdad (check de path/env antes del print).

**Tests:** banner condicional (con/sin rootfs); valor de env exportado en shell.

---

## Fuera de alcance (explícito)

- Tool-calling nativo del motor.
- Unificar 3 tiers de namespace + preload Kotlin (native) — refactor de riesgo, no funcionalidad faltante.
- Doble libro `_pty` (PtyManager vs _TermState) — bug estructural aparte, requiere su propia especificación.
- Restart storm del visor VNC y watchdog sin cleanup — mismo criterio, especificación aparte.
- `LOAD_SYM → _exit(1)` y poll 30s vs timeout 120s (native) — cambios de comportamiento nativo con riesgo, requieren prueba dinámica en device.

## Orden de implementación

1. Sección 1 (agente) — la prioridad del veredicto.
2. Sección 2 (degradación).
3. Sección 3 (puerta RAM).
4. Sección 4 (honestidad).
