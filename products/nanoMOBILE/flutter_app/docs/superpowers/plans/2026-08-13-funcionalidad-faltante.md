# Plan de implementación: Funcionalidad faltante de orquestación

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Cerrar los 4 frentes de funcionalidad faltante del veredicto de orquestación: herramientas de agente faltantes, degradación de contexto real por RAM, puerta de RAM al cargar modelo, y honestidad UI/nativa.

**Architecture:** Se extiende lo existente, no se rehace. El puente agente ya existe (`AgentToolDispatcher` + bucle en `chat_provider._generateRound`) — se añaden 3 herramientas. La degradación se implementa como presupuesto de contexto puro (`ContextBudget`) integrado en `chat_provider` con RAM medida por `DeviceMetrics.fetch()`. La puerta RAM vive en `models_notifier` antes de `selectModel`. Honestidad = 3 fixes puntuales.

**Tech Stack:** Dart 3 (records, switch expressions), Flutter Riverpod (StateNotifier), flutter_test.

**Spec:** `docs/superpowers/specs/2026-08-13-funcionalidad-faltante-design.md`

## Global Constraints

- Filosofía NanoRuntime — cualquier cambio debe cumplir: degradación progresiva (mejor lento y vivo), cero configuración, hardware ~$150, honestidad radical (jamás estado falso).
- Mensajes de error/resultado al usuario siempre en español, tipados, con motivo.
- Tests primero (TDD): escribir test que falle, verificar fallo, implementar mínimo, verificar pase, commit.
- No tocar código nativo (C/Kotlin) salvo que una tarea lo diga explícitamente — ninguna de estas tareas lo requiere.
- `DeviceMetrics.fetch()` es `static Future<DeviceMetricsData>` con `ramAvailableMb` en MB (double) y `ramAvailableGb` getter; `DeviceMetricsData.fallback()` devuelve ceros cuando el canal falla.
- Formato de commit: tipo en español o inglés según repo (`feat:`/`fix:`), final con `Co-Authored-By: Claude <noreply@anthropic.com>`.
- Los tests del repo corren con `flutter test test/agent/...` etc. desde `products/nanoMOBILE/flutter_app`.

---

### Task 1: Herramientas swipe/global/launch en AgentToolDispatcher

**Files:**
- Modify: `lib/core/agent/agent_tool_dispatcher.dart:139-159` (switch `runTool`)
- Modify: `lib/core/providers/chat_provider.dart:48-63` (`_systemPrompt`)
- Test: `test/agent/agent_tool_dispatcher_test.dart` (extender)
- Test: `test/agent/chat_tool_loop_test.dart` (extender)

**Interfaces:**
- Consumes: `NanoRuntimeApi.agentSwipe(double x1, y1, x2, y2, {int durationMs})`, `agentGlobalAction(String)`, `agentLaunchPackage(String)` (existen en `nano_runtime_api.dart:546,580,593`); `NanoSelector.parse`; `_tryParse` ya existente.
- Produces: `runTool` acepta `tool == 'swipe' | 'global' | 'launch'`; strings de resultado en español con prefijo `✅`/`❌`.

- [ ] **Step 1: Test fallante — tool nueva en dispatcher**

En `test/agent/agent_tool_dispatcher_test.dart`, añadir (usa los fakes existentes de `NanoRuntimeApi` de ese archivo):

```dart
test('runTool swipe con selector resuelto ejecuta agentSwipe', () async {
  // fake api con snapshot que resuelve el selector y agentSwipe -> true
  final result = await dispatcher.runTool(
    const ToolCall(tool: 'swipe', selector: 'text=Bluetooth'),
  );
  expect(result, contains('✅'));
});

test('runTool global back ejecuta agentGlobalAction', () async {
  final result = await dispatcher.runTool(
    const ToolCall(tool: 'global', selector: 'back'),
  );
  expect(result, contains('✅'));
});

test('runTool launch ejecuta agentLaunchPackage', () async {
  final result = await dispatcher.runTool(
    const ToolCall(tool: 'launch', selector: 'com.android.settings'),
  );
  expect(result, contains('✅'));
});
```

- [ ] **Step 2: Correr tests, verificar fallo**

Run: `flutter test test/agent/agent_tool_dispatcher_test.dart`
Expected: los 3 tests nuevos FAIL — `runTool` devuelve `'❌ [tool] Herramienta desconocida "swipe"...'`

- [ ] **Step 3: Implementar casos nuevos en runTool**

En `agent_tool_dispatcher.dart`, dentro del switch de `runTool` (tras `case 'back':`), añadir:

```dart
      case 'swipe':
        if (call.selector == null || call.selector!.isEmpty) {
          return '❌ [tool] swipe requiere "selector".';
        }
        return _swipe(call.selector!);
      case 'global':
        if (call.selector == null || call.selector!.isEmpty) {
          return '❌ [tool] global requiere acción (back/home/recents).';
        }
        return _global(call.selector!);
      case 'launch':
        if (call.selector == null || call.selector!.isEmpty) {
          return '❌ [tool] launch requiere "selector" (packageName).';
        }
        return _launch(call.selector!);
```

Y en la sección de implementaciones (tras `_back()`):

```dart
  /// Swipe horizontal sobre el nodo resuelto: de su centro a -60% ancho.
  Future<String> _swipe(String expr) async {
    final (selector, err) = _tryParse(expr);
    if (selector == null) return err!;
    final snap = await _executor.snapshot();
    if (snap == null) return '❌ [serviceOff] Accesibilidad apagada.';
    if (snap.isEmpty) return '❌ [snapshotEmpty] Sin ventana activa.';
    final outcome = _executorNanoSelectorResolve(selector, snap);
    if (!outcome.isResolved) return '❌ [${outcome.status.name}] ${outcome.reason}';
    final b = outcome.best!.node.bounds;
    final cx = b.centerX.round();
    final cy = b.centerY.round();
    final dx = (b.width * 0.6).round().clamp(40, 400);
    final ok = await NanoRuntimeApi.instance.agentSwipe(
      cx.toDouble(), cy.toDouble(), (cx - dx).toDouble(), cy.toDouble());
    return ok
        ? '✅ swipe sobre "${outcome.best!.node.label}"'
        : '❌ [gestureFailed] Swipe falló en el canal.';
  }

  Future<String> _global(String action) async {
    final ok = await NanoRuntimeApi.instance.agentGlobalAction(action);
    return ok
        ? '✅ Acción global "$action" ejecutada.'
        : '❌ [gestureFailed] globalAction("$action") falló.';
  }

  Future<String> _launch(String packageName) async {
    final ok = await NanoRuntimeApi.instance.agentLaunchPackage(packageName);
    return ok
        ? '✅ App "$packageName" lanzada.'
        : '❌ [gestureFailed] launchPackage("$packageName") falló.';
  }
```

`_executorNanoSelectorResolve` no existe: en su lugar usa el resolve público del executor. Cambia `_swipe` para usar:

```dart
    final snap = await _executor.snapshot();
    if (snap == null) return '❌ [serviceOff] Accesibilidad apagada.';
    if (snap.isEmpty) return '❌ [snapshotEmpty] Sin ventana activa.';
    final outcome = _engineResolve(selector, snap);
```

donde `_engineResolve` es:

```dart
  ResolveOutcome _engineResolve(NanoSelector selector, NanoSnapshot snap) =>
      NanoSelectorEngine().resolve(selector, snap);
```

y añade el import `selector_engine.dart` arriba. (El dispatcher no guarda el engine — crea uno por llamada, es puro y barato.)

- [ ] **Step 4: Correr tests, verificar pase**

Run: `flutter test test/agent/agent_tool_dispatcher_test.dart`
Expected: PASS completo (tests nuevos + existentes).

- [ ] **Step 5: Anunciar tools en prompt y test de loop**

En `chat_provider.dart` `_systemPrompt` (líneas 54-61), añadir tras la línea de `{"tool":"back"}`:

```
'{"tool":"swipe","selector":"<sel>"} — deslizar sobre un elemento\n'
'{"tool":"global","selector":"back|home|recents"} — acción global del sistema\n'
'{"tool":"launch","selector":"<packageName>"} — abrir una app por su paquete\n'
```

En `test/agent/chat_tool_loop_test.dart`, añadir un test espejo del existente de tap:

```dart
test('tool-calling: modelo llama launch → se ejecuta y re-genera', () async {
  // misma estructura que el test de tap: primer fullText = '{"tool":"launch",
  // "selector":"com.android.settings"}', segunda generación = respuesta final.
  // Verifica: un mensaje con la llamada, uno con la respuesta, 2 generaciones.
});
```

Reutiliza los fakes ya definidos en ese archivo (motor fake que devuelve secuencias de tokens).

- [ ] **Step 6: Correr tests del loop**

Run: `flutter test test/agent/chat_tool_loop_test.dart test/agent/agent_tool_dispatcher_test.dart`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add lib/core/agent/agent_tool_dispatcher.dart lib/core/providers/chat_provider.dart test/agent/agent_tool_dispatcher_test.dart test/agent/chat_tool_loop_test.dart
git commit -m "feat: herramientas swipe/global/launch en el puente agente del chat

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### Task 2: ContextBudget — presupuesto de contexto puro

**Files:**
- Create: `lib/core/agent/context_budget.dart`
- Test: `test/agent/context_budget_test.dart`

**Interfaces:**
- Consumes: `DeviceMetricsData.ramAvailableGb` (double, GB); `ChatMessage.text`.
- Produces (nombres exactos para tareas siguientes):
  - `class ContextBudget`
  - `static const List<int> tiers = [8192, 4096, 2048, 1024, 512];`
  - `static int tierForRam(double ramAvailableGb, {int previousTier = 8192})` — devuelve un valor de `tiers`.
  - `static int estimateTokens(List<ChatMessage> messages)` — `chars/4` redondeado arriba.
  - `static List<ChatMessage> trim(List<ChatMessage> history, int tierTokens, {required bool keepLastUser})` — recorta por el final del historial hasta caber en el presupuesto; siempre conserva el primer mensaje (system/prompt de arranque) y, si `keepLastUser`, el último usuario.

- [ ] **Step 1: Test fallante**

`test/agent/context_budget_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/core/agent/context_budget.dart';
import 'package:nanoai/core/models/chat_models.dart';

void main() {
  group('tierForRam', () {
    test('sin RAM medida degrada al mínimo', () {
      expect(ContextBudget.tierForRam(0), 512);
    });
    test('umbrales exactos', () {
      expect(ContextBudget.tierForRam(0.4), 512);
      expect(ContextBudget.tierForRam(0.5), 512);   // <512MB
      expect(ContextBudget.tierForRam(0.75), 1024); // <1GB
      expect(ContextBudget.tierForRam(1.5), 2048);  // <2GB
      expect(ContextBudget.tierForRam(3.0), 4096);  // <4GB
      expect(ContextBudget.tierForRam(4.0), 8192);
    });
    test('histéresis: subir exige umbral + 25%', () {
      // previousTier 512, umbral para 1024 es 1.0GB; +25% = 1.25GB
      expect(ContextBudget.tierForRam(1.1, previousTier: 512), 512);
      expect(ContextBudget.tierForRam(1.3, previousTier: 512), 1024);
    });
    test('bajar es inmediato sin histéresis', () {
      expect(ContextBudget.tierForRam(0.8, previousTier: 8192), 1024);
    });
  });

  group('estimateTokens', () {
    test('chars/4 redondeado arriba', () {
      final msgs = [msg('hola'), msg('a' * 100)];
      expect(ContextBudget.estimateTokens(msgs), 25);
    });
  });

  group('trim', () {
    test('conserva primero y último usuario', () {
      final history = [msg('primero'), msg('x' * 1000), msg('ultimo')];
      final t = ContextBudget.trim(history, 100, keepLastUser: true);
      expect(t.first.text, 'primero');
      expect(t.last.text, 'ultimo');
    });
    test('nunca corta a 0', () {
      final history = [msg('primero')];
      expect(ContextBudget.trim(history, 1, keepLastUser: true).length, 1);
    });
  });
}

ChatMessage msg(String t) => ChatMessage(
  id: t, sender: MessageSender.user, text: t, timestamp: DateTime(2026));
```

- [ ] **Step 2: Correr, verificar fallo**

Run: `flutter test test/agent/context_budget_test.dart`
Expected: FAIL — `context_budget.dart` no existe (error de import).

- [ ] **Step 3: Implementar**

```dart
/// ContextBudget — presupuesto de contexto por RAM libre real.
///
/// Pilar 1 (degradación progresiva) y pilar 4 (honestidad): el escalón se
/// elige por RAM medida, la estimación de tokens es declarada (chars/4),
/// y el recorte jamás deja el historial vacío.
library;

import '../models/chat_models.dart';

class ContextBudget {
  ContextBudget._();

  /// Escalones de contexto en tokens, de mejor a peor.
  static const List<int> tiers = [8192, 4096, 2048, 1024, 512];

  /// RAM libre 0 (canal métricas muerto) degrada al mínimo, nunca bloquea.
  static int tierForRam(double ramAvailableGb, {int previousTier = 8192}) {
    if (ramAvailableGb <= 0) return tiers.last;
    final int base;
    if (ramAvailableGb < 0.5) base = 512;
    else if (ramAvailableGb < 1) base = 1024;
    else if (ramAvailableGb < 2) base = 2048;
    else if (ramAvailableGb < 4) base = 4096;
    else base = 8192;
    // Histéresis: subir exige superar el umbral +25% (evita oscilar con GC).
    if (base > previousTier) {
      final gate = _thresholdOf(base) * 1.25;
      if (ramAvailableGb < gate) return previousTier;
    }
    return base;
  }

  static double _thresholdOf(int tier) => switch (tier) {
        1024 => 0.5, 2048 => 1.0, 4096 => 2.0, 8192 => 4.0, _ => 0.0,
      };

  /// Estimación honesta: ~4 chars por token (declarada, no exacta).
  static int estimateTokens(List<ChatMessage> messages) =>
      messages.fold(0, (acc, m) => acc + (m.text.length / 4).ceil());

  /// Recorta [history] por el final hasta caber en [tierTokens].
  /// Conserva siempre el primer mensaje y, si [keepLastUser], el último.
  static List<ChatMessage> trim(
    List<ChatMessage> history,
    int tierTokens, {
    required bool keepLastUser,
  }) {
    if (history.length <= 2) return history;
    final first = history.first;
    final last = history.last;
    final middle = history.sublist(1, history.length - 1);
    var budget = tierTokens - (first.text.length / 4).ceil();
    if (keepLastUser) budget -= (last.text.length / 4).ceil();
    final kept = <ChatMessage>[first];
    for (final m in middle.reversed) {
      final cost = (m.text.length / 4).ceil();
      if (budget - cost < 0) break;
      budget -= cost;
      kept.insert(1, m);
    }
    if (keepLastUser) kept.add(last);
    return kept;
  }
}
```

- [ ] **Step 4: Correr, verificar pase**

Run: `flutter test test/agent/context_budget_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/core/agent/context_budget.dart test/agent/context_budget_test.dart
git commit -m "feat: ContextBudget — degradación de contexto por RAM libre con histéresis

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### Task 3: Integrar ContextBudget en chat_provider + chip de escalón en UI

**Files:**
- Modify: `lib/core/models/chat_models.dart:52-85` (ChatState: campo `contextTier`)
- Modify: `lib/core/providers/chat_provider.dart` (fetch RAM en `send`, reemplazar `_maxHistoryMessages`, inyección de métricas)
- Modify: `lib/features/chat/presentation/screens/chat_screen.dart:197-199` (chip `_TierChip`)
- Test: `test/agent/chat_tool_loop_test.dart` o nuevo `test/agent/chat_context_tier_test.dart`

**Interfaces:**
- Consumes: `ContextBudget.tierForRam`, `ContextBudget.trim`, `ContextBudget.estimateTokens` (Task 2); `DeviceMetrics.fetch()`.
- Produces: `ChatState.contextTier` (int, default 8192); `ChatNotifier({AgentToolDispatcher? toolDispatcher, Future<DeviceMetricsData> Function()? metrics})` — nuevo parámetro opcional inyectable para tests.

- [ ] **Step 1: Test fallante — tier degrada con RAM baja**

Nuevo `test/agent/chat_context_tier_test.dart`:

```dart
test('send con RAM baja baja contextTier y recorta historial', () async {
  // Fakes: motor listo (ensureReady true), generateStream devuelve 1 token.
  // metrics inyectada: DeviceMetricsData(ramAvailableMb: 400, ...)
  final notifier = ChatNotifier.fixed(ref, initial, metrics: () async =>
      const DeviceMetricsData(ramAvailableMb: 400, ramTotalMb: 4096,
        batteryPct: 50, isCharging: false, storageTotalGb: 64,
        storageFreeGb: 32, cpuCores: 8));
  await notifier.send('hola');
  expect(notifier.state.contextTier, 512);
});
```

(Si `ChatNotifier.fixed` no encaja, usa el constructor normal con `ProviderContainer` como hacen los tests existentes de `chat_tool_loop_test.dart` — sigue ese patrón.)

- [ ] **Step 2: Correr, verificar fallo**

Run: `flutter test test/agent/chat_context_tier_test.dart`
Expected: FAIL — `contextTier` no existe en ChatState / `metrics` no aceptado.

- [ ] **Step 3: ChatState.contextTier**

En `chat_models.dart`, añadir campo tras `streamingText`:

```dart
  /// Escalón activo de contexto en tokens (8192→512). Chip visible solo
  /// cuando es menor que el máximo (honestidad: el usuario ve la degradación).
  final int contextTier;
```

En el constructor: `this.contextTier = 8192`. En `copyWith`: `int? contextTier` y `contextTier: contextTier ?? this.contextTier`.

- [ ] **Step 4: ChatNotifier — métricas inyectables y fetch en send**

En `chat_provider.dart`:

```dart
import '../agent/context_budget.dart';
import '../services/device_metrics.dart';
```

Constructor: añadir parámetro `Future<DeviceMetricsData> Function()? metrics` y campo `final Future<DeviceMetricsData> Function() _metrics;` inicializado con `metrics ?? DeviceMetrics.fetch`. Hacer lo mismo en `ChatNotifier.fixed`.

En `send(String text)`, justo antes de `state = state.copyWith(messages: [...state.messages, userMsg], ...)` añadir:

```dart
    // Degradación por RAM real: el escalón baja antes de generar.
    final metrics = await _metrics();
    if (!mounted) return;
    final tier = ContextBudget.tierForRam(
      metrics.ramAvailableGb,
      previousTier: state.contextTier,
    );
```

y añadir `contextTier: tier` a ese `copyWith`.

Eliminar la constante `_maxHistoryMessages` (líneas 35-38) y su uso en `_buildQwenPrompt` (264-266) y `_buildDeepSeekPrompt` (283-285). Reemplazar en ambos builders:

```dart
    final window = ContextBudget.trim(
      history,
      state.contextTier,
      keepLastUser: false,
    );
```

(El último mensaje del usuario se añade aparte en el prompt, no va en `history`.)

- [ ] **Step 5: Correr tests del provider**

Run: `flutter test test/agent/chat_tool_loop_test.dart test/agent/chat_context_tier_test.dart`
Expected: PASS.

- [ ] **Step 6: Chip de escalón en chat_screen**

En `chat_screen.dart`, cambiar el `trailing` de `NanoScreenShell` (línea 199):

```dart
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (state.contextTier < 8192) _TierChip(tier: state.contextTier),
          const SizedBox(width: 8),
          _EngineBadge(online: state.engineOnline),
        ],
      ),
```

Y al final del archivo, nuevo widget privado:

```dart
class _TierChip extends StatelessWidget {
  const _TierChip({required this.tier});
  final int tier;

  @override
  Widget build(BuildContext context) {
    final colors = context.nanoColors;
    final label = tier <= 512 ? 'Eco $tier' : 'Ctx $tier';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: colors.surfaceVariant,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: context.nanoText.labelSmall),
    );
  }
}
```

Ajusta nombres de tokens/colores a los reales del theme del repo (verifica `context.nanoColors`/`context.nanoText` — si el proyecto usa otra API de theme, usa la que usan los widgets vecinos del mismo archivo).

- [ ] **Step 7: Correr análisis**

Run: `flutter analyze lib/core/agent/context_budget.dart lib/core/providers/chat_provider.dart lib/core/models/chat_models.dart lib/features/chat/presentation/screens/chat_screen.dart`
Expected: sin errores nuevos (warnings preexistentes del repo pueden quedar).

- [ ] **Step 8: Commit**

```bash
git add lib/core/models/chat_models.dart lib/core/providers/chat_provider.dart lib/features/chat/presentation/screens/chat_screen.dart test/agent/chat_context_tier_test.dart
git commit -m "feat: degradación de contexto 8192→512 por RAM real con chip honesto en chat

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### Task 4: Puerta de RAM al cargar modelo

**Files:**
- Modify: `lib/features/models/application/models_state.dart` (campo `loadError`)
- Modify: `lib/features/models/application/models_notifier.dart:149-161,242-270`
- Modify: `lib/features/models/presentation/screens/models_screen.dart` (mostrar `loadError`)
- Test: `test/agent/` no — nuevo `test/models_ram_gate_test.dart`

**Interfaces:**
- Consumes: `LocalModel.ramGb` (double, GB — catálogo); `DeviceMetricsData.ramAvailableGb`; `DetectedModel` (sin ramGb — no bloquea).
- Produces: `ModelsState.loadError` (`String?`), `ModelsNotifier({..., Future<DeviceMetricsData> Function()? metrics})`.

- [ ] **Step 1: Test fallante**

`test/models_ram_gate_test.dart` (sigue el patrón de tests de models existentes — busca cómo instancian `ModelsNotifier` con `ProviderContainer`; si hay test existente de models, reutiliza sus fakes):

```dart
test('loadModel bloquea cuando ramGb no cabe en RAM libre', () async {
  // Modelo catálogo con ramGb: 6.0 instalado.
  // metrics inyectada: ramAvailableMb: 2048 (2GB).
  // 6.0 > 2.0 + 0.25 → bloqueado.
  notifier.loadModel(model.id);
  expect(state.loadError, contains('RAM'));
  // selectModel NO se llamó: chatProvider.activeModel no cambió.
});

test('loadModel arranca cuando cabe', () async {
  // ramGb: 1.0, ramAvailableMb: 4096 (4GB) → 1.0 <= 4.25 → arranca.
  notifier.loadModel(model.id);
  expect(state.loadError, isNull);
});

test('useDetected sin ramGb no bloquea (ramUnknown)', () async {
  // DetectedModel sin ramGb: arranca igual, loadError nulo.
});
```

- [ ] **Step 2: Correr, verificar fallo**

Run: `flutter test test/models_ram_gate_test.dart`
Expected: FAIL — `loadError` no existe / no hay bloqueo.

- [ ] **Step 3: ModelsState.loadError**

En `models_state.dart`, añadir campo `final String? loadError;` con `this.loadError` en constructor y en `copyWith` patrón sentinel igual que `scanError`.

- [ ] **Step 4: Puerta en loadModel**

En `models_notifier.dart`, constructor: aceptar `Future<DeviceMetricsData> Function()? metrics` y guardarlo como `_metrics` (default `DeviceMetrics.fetch`). En `loadModel`, tras el guard `if (!item.installed || item.localPath == null) return;`:

```dart
    // Puerta de RAM (pilar 1 y 4): mejor no arrancar que morir por OOM.
    // Margen 256MB para el resto del sistema.
    final metrics = await _metrics();
    if (!mounted) return;
    if (metrics.ramAvailableMb > 0 &&
        item.ramGb > metrics.ramAvailableGb + 0.25) {
      state = state.copyWith(
        loadError: 'El modelo ${item.name} pide ~${item.ramGb} GB y quedan '
            '${metrics.ramAvailableGb.toStringAsFixed(1)} GB libres. '
            'Libera RAM o usa un modelo más pequeño.',
      );
      return;
    }
```

Convertir `loadModel` en `Future<void>` (era `void` — la firma pública cambia; actualiza los callers, que son la UI, sin comportamiento extra).

- [ ] **Step 5: useDetected — no bloquear sin dato**

En `useDetected`, tras `if (!model.usable) return;` añadir comentario + no-puerta:

```dart
    // DetectedModel no declara ramGb: arranca con ramUnknown. Bloquear sin
    // dato violaría pilar 1 (mejor lento y vivo).
```

Sin cambio de comportamiento (solo documenta la decisión del spec).

- [ ] **Step 6: UI muestra loadError**

En `models_screen.dart` línea 94, el widget resumen recibe `error: state.scanError`. Cambiar a:

```dart
            error: state.loadError ?? state.scanError,
```

(`loadError` es el fallo más reciente y más crítico — puerta de RAM. El widget ya renderiza el error con el estilo del repo, no crear widget nuevo.)

- [ ] **Step 7: Correr tests**

Run: `flutter test test/models_ram_gate_test.dart`
Expected: PASS.

- [ ] **Step 8: Commit**

```bash
git add lib/features/models/application/models_state.dart lib/features/models/application/models_notifier.dart lib/features/models/presentation/screens/models_screen.dart test/models_ram_gate_test.dart
git commit -m "feat: puerta de RAM honesta al cargar modelo (sin OOM silencioso)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### Task 5: Honestidad terminal — banner condicional e identidad real

**Files:**
- Modify: `lib/features/terminal/terminal_core.dart:212` (banner), `:284` (env)
- Test: `test/terminal/terminal_screen_test.dart` (extender)

**Interfaces:**
- Consumes: `_initShell` (async, ya existente) y el estado `_shell`/`_rootfs` del widget.
- Produces: env `TERMUX_APK_RELEASE=nanoMOBILE`; banner de rootfs solo si rootfs verificado.

- [ ] **Step 1: Test fallante**

En `test/terminal/terminal_screen_test.dart`, añadir (ajusta al estilo de ese archivo):

```dart
testWidgets('banner rootfs no aparece sin rootfs real', (tester) async {
  // Pump del widget terminal en modo test sin rootfs (usa los mocks que
  // ya usa el archivo para modo offline).
  expect(find.textContaining('rootfs'), findsNothing);
});

test('env TERMUX_APK_RELEASE es nanoMOBILE', () {
  // Si terminal_core expone el env o hay helper testeable, verificar
  // el mapa; si no, verificar que la constante ya no es F_DROID.
  expect(TerminalEnv.termuxApkRelease, 'nanoMOBILE');
});
```

Si el archivo no tiene mocks de rootfs, crea el caso mínimo: pump widget y verificar que el primer `_out` no contiene 'rootfs ARM64' cuando `_shell` es null.

- [ ] **Step 2: Correr, verificar fallo**

Run: `flutter test test/terminal/terminal_screen_test.dart`
Expected: FAIL — banner sigue incondicional / valor F_DROID.

- [ ] **Step 3: Banner condicional**

En `terminal_core.dart` línea 212, reemplazar:

```dart
    _out('NanoTerminal  rootfs ARM64', Ln.header);
```

por:

```dart
    // Honestidad (pilar 4): no anunciar rootfs si aún no está verificado.
    _out('NanoTerminal', Ln.header);
```

Y en `_initShell`, tras el bloque existente de línea 269-271 (`final installed = _rootfs?.isInstalled == true;` y su `_out('[rootfs] detectado...')`), añadir el anuncio honesto:

```dart
    if (!installed) {
      _out('[rootfs] no disponible — modo offline (auto-PTY bash emulado)',
          Ln.warn);
    }
```

(El caso instalado ya imprime la línea `[rootfs] detectado en ...` real.)

- [ ] **Step 4: Identidad real**

Línea 284: `_ctx.env['TERMUX_APK_RELEASE'] = 'F_DROID';` → `'nanoMOBILE'`.

- [ ] **Step 5: Correr tests**

Run: `flutter test test/terminal/terminal_screen_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/features/terminal/terminal_core.dart test/terminal/terminal_screen_test.dart
git commit -m "fix: honestidad terminal — banner rootfs condicional e identidad nanoMOBILE real

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### Task 6: Honestidad launch screen — progreso indeterminado por etapa real

**Files:**
- Modify: `lib/features/desktop/presentation/screens/desktop_launch_screen.dart` (todas las asignaciones de `_progress`, widget `_HeroCard`, `LinearProgressIndicator` línea 664)
- Test: nuevo `test/desktop_launch_progress_test.dart` (función pura)

**Interfaces:**
- Consumes: `desktopStatus.stage` (String: idle/starting/xvnc/rfb/wm/ready).
- Produces: función pura `(String label, double? progress) stagePresentation(String stage)` — `progress` null = indeterminada.

- [ ] **Step 1: Extraer función pura + test fallante**

En `desktop_launch_screen.dart`, crear (fuera de la clase State, al final del archivo o arriba):

```dart
/// Presentación honesta de cada etapa: sin porcentajes inventados (pilar 4).
/// progress null = barra indeterminada.
(String label, double? progress) stagePresentation(String stage) =>
    switch (stage) {
      'starting' || 'xvnc' => ('Iniciando Xvnc', null),
      'rfb' => ('Handshake RFB', null),
      'wm' => ('Entorno openbox', null),
      'ready' => ('Conectando visor', null),
      _ => ('Preparando', null),
    };
```

`test/desktop_launch_progress_test.dart`:

```dart
test('etapas reales no inventan porcentajes', () {
  for (final s in ['starting', 'xvnc', 'rfb', 'wm', 'ready']) {
    final (label, progress) = stagePresentation(s);
    expect(progress, isNull);
    expect(label, isNotEmpty);
  }
});
```

- [ ] **Step 2: Correr, verificar fallo**

Run: `flutter test test/desktop_launch_progress_test.dart`
Expected: FAIL — función no existe.

- [ ] **Step 3: Usar la función pura en _syncFromStatus**

En `_syncFromStatus` (switch de líneas 140-166), reemplazar el switch entero por:

```dart
    final (label, progress) = stagePresentation(desktopStatus.stage);
    _status = label;
    _detail = 'Etapa real del backend: ${desktopStatus.stage}.';
    _stageLabel = label;
    _progress = progress;
    return;
```

Los casos `desktopStatus.installed` (Preparado 50%), `_rootfsReady` (25%) y pendiente (0%) también mienten: pasar a `_progress = null` con labels `'Preparado'`, `'Rootfs listo'`, `'Pendiente'` (sin porcentaje). Mantener solo dos valores determinados: `_progress = 1.0` en `_desktopReady` (Listo) y `_progress = 0.0` en fallo.

- [ ] **Step 4: _prepareStartAndEnter sin pasos inventados**

En `_prepareStartAndEnter` (líneas 200-286): reemplazar cada asignación numérica (`0.15, 0.30, 0.60, 0.85`) por `_progress = null;` y `_stageLabel` con la etapa real del `await` que sigue (Verificando rootfs, Instalando bootstrap, Instalando X11, Arrancando Xvnc...). Mantener `_progress = 1.0` solo al final exitoso (línea 286) y `0.0` en cada fallo.

- [ ] **Step 5: Barra acepta null**

`_HeroCard` recibe `progress: _progress` (línea 368). Cambiar tipo del campo en `_HeroCard` de `double` a `double?` y en la línea 664:

```dart
                    return LinearProgressIndicator(
                      value: progress,
                      ...
                    );
```

(`value: null` = indeterminada, comportamiento nativo de Material.)

- [ ] **Step 6: Correr tests**

Run: `flutter test test/desktop_launch_progress_test.dart test/dashboard_launcher_test.dart`
Expected: PASS (el test de dashboard no debe romperse; si toca launch screen, ajusta solo ese test con la nueva firma).

- [ ] **Step 7: Commit**

```bash
git add lib/features/desktop/presentation/screens/desktop_launch_screen.dart test/desktop_launch_progress_test.dart
git commit -m "fix: honestidad launch screen — progreso indeterminado por etapa real, sin porcentajes inventados

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Verificación final (tras Task 6)

- [ ] `flutter test` completo en `products/nanoMOBILE/flutter_app` — todo PASS.
- [ ] `flutter analyze` — sin errores nuevos.
- [ ] Commit final del spec actualizado (si no se commiteó antes).

## Notas de ejecución

- Todas las tareas son independientes salvo: Task 3 depende de Task 2 (usa `ContextBudget`). El resto puede ir en cualquier orden.
- Si un test existente rompe por cambio de firma (`loadModel` ahora `Future<void>`, `_HeroCard.progress` nullable), ajusta ese test en la misma tarea — no dejes la suite roja.
- No tocar `test/agent/fixtures.dart` salvo que un test nuevo necesite un fixture y no exista; en ese caso añadirlo ahí.
