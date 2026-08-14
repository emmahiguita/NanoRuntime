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

## Sección 1: Puente agente — JSON de acción en prompt

**Decisión:** JSON de acción delimitado en el prompt de sistema, parseado y ejecutado en Dart vía `NanoAgentExecutor`. Descarta tool-calling nativo del motor (depende del backend llama.cpp, más RAM/tokens — viola pilar 3) y regex ad-hoc (frágil).

**Estado actual verificado:**
- `NanoAgentExecutor` existe (`lib/core/agent/agent_executor.dart`) con invariantes completas: snapshot con retry de rebind (3×250ms), resolve ponderado, actionability, settle + re-resolución, gesto solo por centro del bounds.
- Único consumidor: consola manual de Settings (`lib/features/settings/presentation/widgets/agent_console_section.dart:27,40`).
- Chat es completion plano sin tool-calling (`lib/core/providers/chat_provider.dart`).
- Los `@Deprecated` en `nano_runtime_api.dart:490,510` apuntan a clases reales; no hay referencia rota. Corrección al hallazgo de auditoría.

**Componentes nuevos:**

1. `lib/core/agent/agent_action.dart`:
   - `enum AgentActionType { tap, setText, swipe, globalAction, launchPackage }`.
   - `class AgentAction { AgentActionType type; NanoSelector? selector; String? text; ... }`.
   - `static AgentAction? tryParse(String text)`: busca bloque delimitado `[[ACTION:{...}]]`, parsea JSON con tolerancia, valida contra campos de `NanoSelector`. Puro, sin canal, testable.
2. Prompt de sistema en `chat_provider.dart`: instrucción corta al modelo para emitir `[[ACTION:{"action":"tap","selector":{"text":"..."}}]]` únicamente cuando deba actuar sobre la UI. Un bloque por turno.
3. Bucle de ejecución en el provider:
   - Tras streaming completo: si `tryParse` devuelve acción → ejecutar con `NanoAgentExecutor` (inyectable para tests).
   - Resultado tipado `AgentExecutionResult` se inyecta como mensaje del sistema al historial; el modelo continúa con el contexto del resultado.
   - Máximo 3 ciclos de acción por turno del usuario (anti-bucle, pilar 1).
4. Degradación: sin bloque de acción → chat normal. Canal muerto (`serviceOff`) → resultado honesto al usuario, sin reintento infinito.

**Flujo de datos:** `modelo → texto con [[ACTION]] → tryParse → NanoAgentExecutor → AgentExecutionResult → historial → modelo`.

**Manejo de errores:** JSON roto → ignorado, chat normal (el modelo ve el texto tal cual, sin acción). Acción no resuelta (`notFound`/`ambiguous`/`notActionable`) → resultado tipado al historial con motivo en español.

**Tests:** parser puro (bloque válido, JSON roto, sin bloque, dos bloques = primero gana); integración con fakes de `NanoRuntimeApi` y `NanoAgentExecutor` inyectado; límite de 3 ciclos.

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
