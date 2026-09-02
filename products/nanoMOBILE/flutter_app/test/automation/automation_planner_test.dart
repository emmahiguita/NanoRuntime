import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/core/services/llm_engine_client.dart';
import 'package:nanoai/features/automation/engine/execution/agent_tool_dispatcher.dart'
    show AgentToolDispatcher;
import 'package:nanoai/features/automation/engine/planning/automation_planner.dart';
import 'package:nanoai/features/automation/application/automation_coordinator.dart';
import 'package:nanoai/features/automation/domain/automation_goal.dart';
import 'package:nanoai/features/automation/domain/automation_result.dart';
import 'package:nanoai/features/automation/domain/automation_policy.dart';

/// Cliente LLM fake: devuelve un texto canjeado (la lógica de parsing/validación
/// del planner es REAL; el motor/no se toca → no se inventa hardware).
class _FakeClient extends LLMEngineClient {
  final String canned;
  _FakeClient(this.canned);

  @override
  Future<LLMResult> generate({
    required String prompt,
    double temperature = 0.7,
    int maxTokens = 256,
  }) async => LLMResult(text: canned);
}

/// Planner fake que siempre devuelve vacío (para probar que execute lo llama
/// y degrada a noPlan, sin ejecutar tools → sin IO del dispatcher).
class _EmptyPlanner implements AutomationPlanner {
  @override
  Future<PlannedPlan> plan(String goal) async => const PlannedPlan(
    calls: [],
    generated: 0,
    rejected: 0,
    llmLatency: Duration.zero,
  );
}

void main() {
  group('LlmAutomationPlanner · parseo y validación REAL', () {
    test('parsea un array JSON válido en ToolCalls', () async {
      final p = LlmAutomationPlanner(
        client: _FakeClient(
          '[{"tool":"tap","selector":"text=Bluetooth"},'
          '{"tool":"write","text":"hola"}]',
        ),
      );
      final pp = await p.plan('');
      final calls = pp.calls;
      expect(calls, hasLength(2));
      expect(calls.first.tool, 'tap');
      expect(calls.first.selector, 'text=Bluetooth');
      expect(calls.last.tool, 'write');
      expect(calls.last.text, 'hola');
    });

    test(
      'descarta tools desconocidas (salida del modelo es dato NO fiable)',
      () async {
        final p = LlmAutomationPlanner(
          client: _FakeClient('[{"tool":"hack","selector":"x"}]'),
        );
        expect((await p.plan('')).calls, isEmpty);
      },
    );

    test('descarta llamadas sin selector ni texto (no ejecutables)', () async {
      final p = LlmAutomationPlanner(
        client: _FakeClient('[{"tool":"tap"},{"tool":"write","text":"ok"}]'),
      );
      final calls = (await p.plan('')).calls;
      expect(calls, hasLength(1));
      expect(calls.single.tool, 'write');
    });

    test('salida malformada → vacío (noPlan honesto aguas arriba)', () async {
      final p = LlmAutomationPlanner(client: _FakeClient('no soy json'));
      expect((await p.plan('')).calls, isEmpty);
    });
  });

  group('LlmAutomationPlanner · validación endurecida (false success)', () {
    test('write "" (texto vacío) se descarta', () async {
      final p = LlmAutomationPlanner(
        client: _FakeClient('[{"tool":"write","text":""}]'),
      );
      expect((await p.plan('')).calls, isEmpty);
    });

    test('back con selector se descarta (es sin parámetros)', () async {
      final p = LlmAutomationPlanner(
        client: _FakeClient('[{"tool":"back","selector":"text=Bluetooth"}]'),
      );
      expect((await p.plan('')).calls, isEmpty);
    });

    test('screen con selector se descarta (solo lectura)', () async {
      final p = LlmAutomationPlanner(
        client: _FakeClient('[{"tool":"screen","selector":"id=resourceId"}]'),
      );
      expect((await p.plan('')).calls, isEmpty);
    });

    test(
      'placeholder id=resourceId se descarta (copiado del prompt)',
      () async {
        final p = LlmAutomationPlanner(
          client: _FakeClient('[{"tool":"tap","selector":"id=resourceId"}]'),
        );
        expect((await p.plan('')).calls, isEmpty);
      },
    );

    test('plan válido (tap text=Bluetooth) se conserva', () async {
      final p = LlmAutomationPlanner(
        client: _FakeClient('[{"tool":"tap","selector":"text=Bluetooth"}]'),
      );
      expect((await p.plan('')).calls, hasLength(1));
    });
  });

  group('AutomationCoordinator.execute · planner real', () {
    test('con planner que no produce acciones → noPlan honesto', () async {
      final c = AutomationCoordinator(
        dispatcher: AgentToolDispatcher(),
        mode: () => AgentAutomationMode.autonomous,
        planner: _EmptyPlanner(),
      );
      final r = await c.execute(const AutomationGoal(text: 'abre bluetooth'));
      expect(r.status, AutomationResultStatus.noPlan);
    });
  });
}
