import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/automation/engine/perception/actionability_engine.dart';
import 'package:nanoai/features/automation/engine/execution/agent_executor.dart';
import 'package:nanoai/features/automation/engine/execution/agent_tool_dispatcher.dart';
import 'package:nanoai/features/automation/engine/execution/goal_verifier.dart';
import 'package:nanoai/features/automation/engine/execution/nano_flow.dart';

import 'fixtures.dart';

/// Tests del NanoFlowExecutor (C8): flujo verificado se ejecuta determinista
/// con la MISMA gobernanza que el plan del LLM + verificación de objetivo.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.nanoai/agent');

  final methodCalls = <String>[];
  final tapCalls = <List<int>>[];
  var dumpProvider = () => snapshotAjustes();
  var snapshots = <Map<String, dynamic>>[];

  late AgentToolDispatcher dispatcher;
  late NanoFlowExecutor executor;

  setUp(() {
    methodCalls.clear();
    tapCalls.clear();
    snapshots = [snapshotAjustes()];
    dumpProvider = () {
      // El mundo avanza por la secuencia de snapshots simulada.
      if (snapshots.isNotEmpty) {
        final snap = snapshots.first;
        return snap;
      }
      return snapshotAjustes();
    };
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          methodCalls.add(call.method);
          switch (call.method) {
            case 'dumpSnapshot':
              return dumpProvider();
            case 'tapAt':
              final args = call.arguments as Map;
              tapCalls.add([args['x'] as int, args['y'] as int]);
              if (snapshots.length > 1) snapshots.removeAt(0);
              return true;
            case 'inputText':
              return true;
            case 'globalAction':
              if (snapshots.length > 1) snapshots.removeAt(0);
              return true;
            default:
              return null;
          }
        });
    dispatcher = AgentToolDispatcher(
      executor: NanoAgentExecutor(
        stability: const StabilityChecker(
          wait: Duration.zero,
          maxCenterDeltaPx: 24,
          maxSizeChangeRatio: 0.10,
        ),
      ),
    );
    executor = NanoFlowExecutor(
      dispatcher: dispatcher,
      goalVerifier: GoalVerifier(
        executor: NanoAgentExecutor(
          stability: const StabilityChecker(
            wait: Duration.zero,
            maxCenterDeltaPx: 24,
            maxSizeChangeRatio: 0.10,
          ),
        ),
      ),
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  group('NanoFlowExecutor', () {
    test('flow solo-lectura verificado → completed sin LLM', () async {
      final flow = NanoFlow(
        goal: 'verificar ajustes',
        steps: const [
          ToolCall(tool: 'screen'),
          ToolCall(tool: 'resolve', selector: 'text=Bluetooth'),
        ],
      );
      final r = await executor.execute(flow);
      expect(r.completed, isTrue);
      expect(r.plan.completed, isTrue);
      expect(tapCalls, isEmpty);
    });

    test('flow con expectativa de objetivo cumplida → completed', () async {
      final flow = NanoFlow(
        goal: 'verificar estado de Bluetooth',
        steps: const [ToolCall(tool: 'screen')],
        goalExpectation: const GoalExpectation(visibleText: 'Bluetooth'),
      );
      final r = await executor.execute(flow);
      expect(r.completed, isTrue);
      expect(r.goal.status, GoalStatus.satisfied);
    });

    test('flow sin confirmar con paso sensible → pausa (no ejecuta)', () async {
      snapshots = [snapshotAjustes(), snapshotDobleAceptar()];
      final flow = NanoFlow(
        goal: 'abre bluetooth',
        steps: const [ToolCall(tool: 'tap', selector: 'text=Bluetooth')],
      );
      final r = await executor.execute(flow);
      expect(r.completed, isFalse);
      expect(r.plan.pauseIndex, 0); // tap del LLM exige confirmación
      expect(tapCalls, isEmpty);

      // Confirmado → ejecuta y completa.
      final confirmed = await executor.execute(flow, confirmed: true);
      expect(confirmed.completed, isTrue);
      expect(tapCalls, hasLength(1));
    });

    test('flow cuyo paso falla → completed=false con goal no satisfecho',
        () async {
      final flow = NanoFlow(
        goal: 'verificar estado de Bluetooth',
        steps: const [
          ToolCall(tool: 'screen'),
          ToolCall(tool: 'resolve', selector: 'text=Inexistente'),
        ],
        goalExpectation: const GoalExpectation(visibleText: 'Bluetooth'),
      );
      final r = await executor.execute(flow);
      expect(r.completed, isFalse);
      expect(r.plan.completed, isFalse);
      expect(r.goal.status, GoalStatus.notSatisfied);
    });
  });
}
