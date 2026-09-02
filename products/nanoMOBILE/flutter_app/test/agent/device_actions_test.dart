import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/core/services/llm_engine_client.dart';
import 'package:nanoai/features/automation/engine/execution/agent_executor.dart';
import 'package:nanoai/features/automation/engine/execution/agent_tool_dispatcher.dart';
import 'package:nanoai/features/automation/engine/execution/agent_tool_prompt.dart';
import 'package:nanoai/features/automation/engine/execution/tool_registry.dart';
import 'package:nanoai/features/automation/engine/perception/actionability_engine.dart';
import 'package:nanoai/features/automation/engine/planning/automation_planner.dart';

import 'fixtures.dart';

/// Tests de Device Actions V1 (A1): capacidades nativas ya existentes en el
/// AccessibilityService elevadas a tools tipadas. Verifican que:
///  - las tools están disponibles pero NO anunciadas al LLM;
///  - el dispatcher enruta cada acción al transporte correcto;
///  - `dispatchGesture == true` NO se reporta como éxito sin cambio observable;
///  - la política sigue frenando la agencia autónoma.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.nanoai/agent');

  final globalActions = <String>[];
  final swipes = <List<int>>[];
  final longPresses = <List<int>>[];
  var dumpProvider = () => snapshotAjustes();
  var globalActionOk = true;

  late AgentToolDispatcher dispatcher;

  setUp(() {
    globalActions.clear();
    swipes.clear();
    longPresses.clear();
    dumpProvider = () => snapshotAjustes();
    globalActionOk = true;
    dispatcher = AgentToolDispatcher(
      executor: NanoAgentExecutor(
        stability: const StabilityChecker(wait: Duration.zero),
      ),
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          switch (call.method) {
            case 'dumpSnapshot':
              return dumpProvider();
            case 'globalAction':
              final args = call.arguments as Map;
              globalActions.add(args['action'] as String);
              return globalActionOk;
            case 'swipe':
              final args = call.arguments as Map;
              swipes.add([
                args['x1'] as int,
                args['y1'] as int,
                args['x2'] as int,
                args['y2'] as int,
              ]);
              return true;
            case 'longPressAt':
              final args = call.arguments as Map;
              longPresses.add([args['x'] as int, args['y'] as int]);
              return true;
            default:
              return null;
          }
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  group('ToolRegistry · Device Actions V1', () {
    test('las 7 tools están registradas', () {
      for (final name in [
        'home',
        'recents',
        'open_notifications',
        'open_quick_settings',
        'swipe',
        'scroll',
        'long_press',
      ]) {
        expect(ToolRegistry.builtin.lookup(name), isNotNull, reason: name);
      }
    });

    test('las device actions no se anuncian al LLM (promptSyntax null)', () {
      for (final name in [
        'home',
        'recents',
        'open_notifications',
        'open_quick_settings',
        'swipe',
        'scroll',
        'long_press',
      ]) {
        expect(
          ToolRegistry.builtin.lookup(name)!.promptSyntax,
          isNull,
          reason: name,
        );
      }
    });
  });

  group('global actions', () {
    test('@home enruta a GLOBAL_ACTION_HOME y verifica cambio', () async {
      dumpProvider = () =>
          globalActions.isNotEmpty ? snapshotDobleAceptar() : snapshotAjustes();
      final r = await dispatcher.runCommand('@home');
      expect(globalActions, ['home']);
      expect(r, contains('Pantalla de inicio ejecutado'));
      expect(r, contains('verificado'));
    });

    test('@sombra enruta a GLOBAL_ACTION_NOTIFICATIONS', () async {
      dumpProvider = () =>
          globalActions.isNotEmpty ? snapshotDobleAceptar() : snapshotAjustes();
      await dispatcher.runCommand('@sombra');
      expect(globalActions, ['notifications']);
    });

    test('@recents enruta a GLOBAL_ACTION_RECENTS', () async {
      dumpProvider = () =>
          globalActions.isNotEmpty ? snapshotDobleAceptar() : snapshotAjustes();
      await dispatcher.runCommand('@recents');
      expect(globalActions, ['recents']);
    });

    test('@quick_settings enruta a GLOBAL_ACTION_QUICK_SETTINGS', () async {
      dumpProvider = () =>
          globalActions.isNotEmpty ? snapshotDobleAceptar() : snapshotAjustes();
      await dispatcher.runCommand('@quick_settings');
      expect(globalActions, ['quick_settings']);
    });

    test('gesto aceptado sin cambio observable → no éxito limpio', () async {
      // dumpProvider fijo: mustChangeSnapshot falla → [verify:*].
      final r = await dispatcher.runCommand('@home');
      expect(globalActions, ['home']);
      expect(r, contains('Pantalla de inicio ejecutado'));
      expect(r, contains('[verify:'));
    });

    test('global action fallida → [gestureFailed]', () async {
      globalActionOk = false;
      final r = await dispatcher.runCommand('@home');
      expect(r, contains('[gestureFailed]'));
    });

    test('home autónomo pide confirmación (policy)', () async {
      final outcome = await dispatcher.runToolGuarded(
        const ToolCall(tool: 'home'),
      );
      expect(outcome.needsConfirmation, isTrue);
      expect(globalActions, isEmpty);
    });
  });

  group('gestos', () {
    test('swipe ejecuta con args tipados', () async {
      dumpProvider = () =>
          swipes.isNotEmpty ? snapshotDobleAceptar() : snapshotAjustes();
      final r = await dispatcher.runToolGuarded(
        const ToolCall(
          tool: 'swipe',
          args: {'startX': 100, 'startY': 1000, 'endX': 100, 'endY': 400},
        ),
        confirmed: true,
      );
      expect(swipes, [
        [100, 1000, 100, 400],
      ]);
      expect(r.feedback, contains('Deslizamiento ejecutado'));
      expect(r.feedback, contains('verificado'));
    });

    test('swipe args incompletos → [tool] sin gesto', () async {
      final r = await dispatcher.runToolGuarded(
        const ToolCall(tool: 'swipe', args: {'startX': 100}),
        confirmed: true,
      );
      expect(r.feedback, contains('[tool] swipe requiere args'));
      expect(swipes, isEmpty);
    });

    test('scroll down resuelve coordenadas del viewport (dedo baja)', () async {
      dumpProvider = () =>
          swipes.isNotEmpty ? snapshotDobleAceptar() : snapshotAjustes();
      final r = await dispatcher.runToolGuarded(
        const ToolCall(tool: 'scroll', args: {'direction': 'down'}),
        confirmed: true,
      );
      expect(swipes, hasLength(1));
      final s = swipes.single;
      expect(s[0], s[2]); // vertical: misma x
      expect(s[1], lessThan(s[3])); // dedo baja (y1 < y2)
      expect(r.feedback, contains('Scroll down ejecutado'));
    });

    test('scroll dirección inválida → [tool] sin gesto', () async {
      final r = await dispatcher.runToolGuarded(
        const ToolCall(tool: 'scroll', args: {'direction': 'diagonal'}),
        confirmed: true,
      );
      expect(r.feedback, contains('[tool] scroll direction inválida'));
      expect(swipes, isEmpty);
    });

    test('long_press ejecuta con args tipados', () async {
      dumpProvider = () =>
          longPresses.isNotEmpty ? snapshotDobleAceptar() : snapshotAjustes();
      final r = await dispatcher.runToolGuarded(
        const ToolCall(
          tool: 'long_press',
          args: {'x': 540, 'y': 340, 'durationMs': 800},
        ),
        confirmed: true,
      );
      expect(longPresses, [
        [540, 340],
      ]);
      expect(r.feedback, contains('Pulsación larga ejecutada'));
    });

    test('long_press args incompletos → [tool] sin gesto', () async {
      final r = await dispatcher.runToolGuarded(
        const ToolCall(tool: 'long_press', args: {'x': 540}),
        confirmed: true,
      );
      expect(r.feedback, contains('[tool] long_press requiere args'));
      expect(longPresses, isEmpty);
    });
  });

  group('exposición autónoma (grounding)', () {
    test('el planner autónomo no conoce launch_app ni gestos', () async {
      final p = LlmAutomationPlanner(
        client: _CannedClient(
          '[{"tool":"launch_app","selector":"com.foo.bar"},'
          '{"tool":"swipe","args":{"startX":0,"startY":0,"endX":0,"endY":0}},'
          '{"tool":"home"}]',
        ),
      );
      final calls = (await p.plan('abre algo')).calls;
      expect(calls, isEmpty);
    });

    test('el prompt del chat no anuncia device actions', () {
      final prompt = AgentToolPrompt.build(ToolRegistry.builtin);
      for (final name in [
        'home',
        'recents',
        'open_notifications',
        'open_quick_settings',
        'swipe',
        'scroll',
        'long_press',
      ]) {
        expect(prompt, isNot(contains('{"tool":"$name"')), reason: name);
      }
    });
  });
}

/// Cliente LLM fake: devuelve un texto canjeado (el parsing/validación del
/// planner es REAL; el motor no se toca).
class _CannedClient extends LLMEngineClient {
  final String canned;
  _CannedClient(this.canned);

  @override
  Future<LLMResult> generate({
    required String prompt,
    double temperature = 0.7,
    int maxTokens = 256,
  }) async => LLMResult(text: canned);
}
