/// Tests del ToolRegistry + PolicyEngine (§12 del plan) y de su integración
/// en AgentToolDispatcher: la política gobierna TODA ejecución (comandos `@`
/// del usuario con confirmación implícita, tool-calling del LLM con
/// confirmación explícita para escrituras externas).
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/automation/engine/execution/agent_executor.dart';
import 'package:nanoai/features/automation/engine/execution/agent_tool_dispatcher.dart';
import 'package:nanoai/features/automation/engine/execution/tool_registry.dart';
import 'package:nanoai/core/services/nano_runtime_api.dart';

import 'fixtures.dart';

/// API falsa: registra gestos/inputs sin MethodChannel. [snapshotRaw] es el
/// árbol crudo que devuelve dumpSnapshot (fixtures reales del canal).
class FakeAgentApi extends NanoRuntimeApi {
  FakeAgentApi({this.snapshotRaw, this.snapshotFuture});

  final Map<String, dynamic>? snapshotRaw;

  /// Si se provee, dumpSnapshot espera ESTE future (para tests de timeout —
  /// un completer nunca completado no deja timers pendientes).
  final Future<Map<dynamic, dynamic>?>? snapshotFuture;

  final List<String> taps = [];
  final List<String> inputs = [];
  final List<String> globalActions = [];

  /// Simula el efecto visible de una escritura: el texto queda en el nodo
  /// editable enfocado → la verificación del AgentLoop pasa en el 1er intento.
  String? visibleText;

  @override
  Future<Map<dynamic, dynamic>?> agentDumpSnapshot() async {
    if (snapshotFuture != null) return snapshotFuture;
    if (visibleText == null || snapshotRaw == null) return snapshotRaw;
    final nodes = (snapshotRaw!['nodes'] as List).map((n) {
      final m = Map<String, dynamic>.from(n as Map);
      if (m['editable'] == true && m['focused'] == true) {
        m['text'] = visibleText;
      }
      return m;
    }).toList();
    return {'package': snapshotRaw!['package'], 'nodes': nodes};
  }

  @override
  Future<bool> agentTapAt(int x, int y) async {
    taps.add('$x,$y');
    return true;
  }

  @override
  Future<bool> agentInputText(String text) async {
    inputs.add(text);
    visibleText = text;
    return true;
  }

  @override
  Future<bool> agentGlobalAction(String action) async {
    globalActions.add(action);
    return true;
  }
}

/// Registry con timeout mínimo para probar la cancelación por timeout.
ToolRegistry slowRegistry() => ToolRegistry({
  'screen': const ToolDefinition(
    name: 'screen',
    risk: ToolRisk.read,
    timeout: Duration(milliseconds: 30),
    description: 'Leer pantalla (lenta)',
  ),
});

/// snapshotAjustes con el campo editable YA enfocado: setText escribe
/// directo sin el tap de foco (el fake no simula el cambio de foco).
Map<String, dynamic> snapshotCampoEnfocado() {
  final s = snapshotAjustes();
  final nodes = (s['nodes'] as List).map((n) {
    final m = Map<String, dynamic>.from(n as Map);
    if (m['editable'] == true) m['focused'] = true;
    return m;
  }).toList();
  return {'package': s['package'], 'nodes': nodes};
}

void main() {
  group('ToolRegistry', () {
    final registry = ToolRegistry.builtin;

    test('lookup canónico', () {
      expect(registry.lookup('tap')!.risk, ToolRisk.device);
      expect(registry.lookup('write')!.requiresConfirmation, isTrue);
      expect(registry.lookup('back')!.timeout, const Duration(seconds: 5));
    });

    test('alias de verbos @ en español', () {
      expect(registry.lookup('pantalla')!.name, 'screen');
      expect(registry.lookup('resolver')!.name, 'resolve');
      expect(registry.lookup('tocar')!.name, 'tap');
      expect(registry.lookup('escribir')!.name, 'write');
      expect(registry.lookup('atras')!.name, 'back');
      expect(registry.lookup('atrás')!.name, 'back');
    });

    test('desconocida → null (nunca se ejecuta fuera del registro)', () {
      expect(registry.lookup('rm'), isNull);
      expect(registry.lookup('shell'), isNull);
      expect(registry.isKnown('bash'), isFalse);
    });
  });

  group('PolicyEngine', () {
    final policy = PolicyEngine();

    test('write del LLM sin confirmación → needsConfirmation', () {
      final d = policy.decide('write', stepsUsed: 0);
      expect(d.needsConfirmation, isTrue);
      expect(d.tool!.name, 'write');
      expect(d.reason, contains('confirmación'));
    });

    test('write con autoría humana → allow (confirmación implícita)', () {
      final d = policy.decide('write', stepsUsed: 0, humanInitiated: true);
      expect(d.allowed, isTrue);
    });

    test('write confirmado explícitamente → allow', () {
      final d = policy.decide('write', stepsUsed: 0, confirmed: true);
      expect(d.allowed, isTrue);
    });

    test('read no pide confirmacion; device autonomo pide confirmacion', () {
      expect(policy.decide('screen', stepsUsed: 0).allowed, isTrue);
      expect(policy.decide('tap', stepsUsed: 0).needsConfirmation, isTrue);
      expect(policy.decide('back', stepsUsed: 0).needsConfirmation, isTrue);
      expect(
        policy.decide('tap', stepsUsed: 0, humanInitiated: true).allowed,
        isTrue,
      );
    });

    test('fuera del registro → denied con motivo', () {
      final d = policy.decide('reboot', stepsUsed: 0);
      expect(d.denied, isTrue);
      expect(d.reason, contains('no está en el registro'));
    });

    test('presupuesto de pasos agotado → denied (anti-bucle)', () {
      final strict = PolicyEngine(maxStepsPerTurn: 2);
      expect(
        strict.decide('tap', stepsUsed: 1, confirmed: true).allowed,
        isTrue,
      );
      expect(
        strict.decide('tap', stepsUsed: 2, confirmed: true).denied,
        isTrue,
      );
      // El presupuesto gana incluso con confirmación: no hay paso extra.
      expect(
        strict.decide('write', stepsUsed: 2, confirmed: true).denied,
        isTrue,
      );
    });
  });

  group('AgentToolDispatcher con política', () {
    test('write del LLM no se ejecuta sin confirmación', () async {
      final api = FakeAgentApi(snapshotRaw: snapshotAjustes());
      final dispatcher = AgentToolDispatcher(
        executor: NanoAgentExecutor(api: api),
      );

      final outcome = await dispatcher.runToolGuarded(
        const ToolCall(tool: 'write', text: 'hola', selector: 'editable=true'),
      );

      expect(outcome.needsConfirmation, isTrue);
      expect(outcome.pendingCall!.tool, 'write');
      expect(api.inputs, isEmpty, reason: 'política debe frenar la ejecución');
      expect(api.taps, isEmpty);
    });

    test('write confirmado ejecuta la escritura', () async {
      final api = FakeAgentApi(snapshotRaw: snapshotCampoEnfocado());
      final dispatcher = AgentToolDispatcher(
        executor: NanoAgentExecutor(api: api),
      );

      final outcome = await dispatcher.runToolGuarded(
        const ToolCall(tool: 'write', text: 'hola', selector: 'editable=true'),
        confirmed: true,
      );

      expect(outcome.verdict, PolicyVerdict.allow);
      expect(api.inputs, ['hola']);
    });

    test('@escribir humano ejecuta sin confirmación', () async {
      final api = FakeAgentApi(snapshotRaw: snapshotCampoEnfocado());
      final dispatcher = AgentToolDispatcher(
        executor: NanoAgentExecutor(api: api),
      );

      final feedback = await dispatcher.runCommand(
        '@escribir hola | editable=true',
      );

      expect(api.inputs, ['hola']);
      expect(feedback, contains('hola'));
    });

    test(
      '@tap humano resuelve y toca el nodo (selector engine real)',
      () async {
        final api = FakeAgentApi(snapshotRaw: snapshotAjustes());
        final dispatcher = AgentToolDispatcher(
          executor: NanoAgentExecutor(api: api),
        );

        final feedback = await dispatcher.runCommand('@tap text=Aceptar');

        expect(api.taps, isNotEmpty);
        expect(feedback, contains('Aceptar'));
      },
    );

    test('tool fuera del registro → denied, el modelo ve el motivo', () async {
      final dispatcher = AgentToolDispatcher(
        executor: NanoAgentExecutor(api: FakeAgentApi()),
      );

      final outcome = await dispatcher.runToolGuarded(
        const ToolCall(tool: 'shell', selector: 'id'),
      );

      expect(outcome.verdict, PolicyVerdict.denied);
      expect(outcome.feedback, contains('[policy]'));
    });

    test('presupuesto real: el tercer paso del turno se deniega', () async {
      final dispatcher = AgentToolDispatcher(
        executor: NanoAgentExecutor(api: FakeAgentApi()),
        policy: PolicyEngine(maxStepsPerTurn: 2),
      );

      // El presupuesto vive en [ToolExecutionBudget], compartido por las
      // llamadas de un mismo turno (write sin selector → allow y falla en
      // validación, sin tocar executor).
      final budget = ToolExecutionBudget();
      final o1 = await dispatcher.runToolGuarded(
        const ToolCall(tool: 'write', selector: ''),
        confirmed: true,
        budget: budget,
      );
      final o2 = await dispatcher.runToolGuarded(
        const ToolCall(tool: 'write', selector: ''),
        confirmed: true,
        budget: budget,
      );
      final o3 = await dispatcher.runToolGuarded(
        const ToolCall(tool: 'write', selector: ''),
        confirmed: true,
        budget: budget,
      );

      expect(o1.verdict, PolicyVerdict.allow);
      expect(o2.verdict, PolicyVerdict.allow);
      expect(o3.verdict, PolicyVerdict.denied);
      expect(o3.feedback, contains('límite de pasos'));
      expect(budget.stepsUsed, 2);
    });

    test(
      'standalone sin budget: cada llamada es un turno fresco',
      () async {
        final dispatcher = AgentToolDispatcher(
          executor: NanoAgentExecutor(api: FakeAgentApi()),
          policy: PolicyEngine(maxStepsPerTurn: 2),
        );
        // Sin budget compartido no hay herencia de pasos: ninguna llamada
        // ve los pasos de la anterior (resetTurn es no-op de compatibilidad).
        final o1 = await dispatcher.runToolGuarded(
          const ToolCall(tool: 'write', selector: ''),
          confirmed: true,
        );
        final o2 = await dispatcher.runToolGuarded(
          const ToolCall(tool: 'write', selector: ''),
          confirmed: true,
        );
        expect(o1.verdict, PolicyVerdict.allow);
        expect(o2.verdict, PolicyVerdict.allow);
      },
    );

    test('timeout: tool colgado se cancela con feedback legible', () async {
      // Completer nunca completado: la llamada cuelga para siempre, el
      // timeout del registro la corta. Sin timers pendientes al terminar.
      final never = Completer<Map<dynamic, dynamic>?>();
      final dispatcher = AgentToolDispatcher(
        executor: NanoAgentExecutor(
          api: FakeAgentApi(snapshotFuture: never.future),
        ),
        registry: slowRegistry(),
      );

      final outcome = await dispatcher.runToolGuarded(
        const ToolCall(tool: 'screen'),
      );

      expect(outcome.verdict, PolicyVerdict.allow);
      expect(outcome.feedback, contains('[timeout]'));
    });

    test('runTool legacy degrada la confirmación a texto (compat)', () async {
      final dispatcher = AgentToolDispatcher(
        executor: NanoAgentExecutor(api: FakeAgentApi()),
      );

      final feedback = await dispatcher.runTool(
        const ToolCall(tool: 'write', text: 'x', selector: 'editable=true'),
      );

      expect(feedback, contains('[policy]'));
      expect(feedback, contains('confirmación'));
    });
  });
}
