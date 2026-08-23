import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/automation/engine/execution/agent_executor.dart';
import 'package:nanoai/features/automation/engine/execution/agent_result.dart';
import 'package:nanoai/features/automation/engine/execution/goal_verifier.dart';
import 'package:nanoai/features/automation/engine/perception/nano_selector.dart';
import 'package:nanoai/features/automation/engine/perception/nano_snapshot.dart';

import 'fixtures.dart';

/// Tests del GoalVerifier (C3): distingue ACTION SUCCESS de TASK SUCCESS.
/// Nunca declara éxito sin evidencia contra el estado real.
void main() {
  group('GoalVerifier', () {
    test('plan incompleto → notSatisfied, nunca éxito', () async {
      final v = GoalVerifier(executor: _FakeExecutor(snapshotAjustes()));
      final r = await v.verify(
        'abre ajustes y vuelve',
        planCompleted: false,
      );
      expect(r.status, GoalStatus.notSatisfied);
    });

    test('plan completo sin expectativa → unverified (honesto, no inventado)',
        () async {
      final v = GoalVerifier(executor: _FakeExecutor(snapshotAjustes()));
      final r = await v.verify('abre ajustes y vuelve', planCompleted: true);
      expect(r.status, GoalStatus.unverified);
    });

    test('expectativa visibleText cumplida → satisfied', () async {
      // snapshotAjustes contiene el nodo "Bluetooth".
      final v = GoalVerifier(executor: _FakeExecutor(snapshotAjustes()));
      final r = await v.verify(
        'verificar estado de Bluetooth',
        planCompleted: true,
        expectation: const GoalExpectation(visibleText: 'Bluetooth'),
      );
      expect(r.status, GoalStatus.satisfied);
    });

    test('expectativa visibleText ausente → notSatisfied (nunca convertir '
        'Wi-Fi en Bluetooth)', () async {
      // snapshotDobleAceptar NO tiene Bluetooth: la expectativa no se cumple.
      final v = GoalVerifier(executor: _FakeExecutor(snapshotDobleAceptar()));
      final r = await v.verify(
        'verificar estado de Bluetooth',
        planCompleted: true,
        expectation: const GoalExpectation(visibleText: 'Bluetooth'),
      );
      expect(r.status, GoalStatus.notSatisfied);
      expect(r.reason, contains('no está en el estado real'));
    });

    test('expectativa absentText sigue presente → notSatisfied', () async {
      final v = GoalVerifier(executor: _FakeExecutor(snapshotAjustes()));
      final r = await v.verify(
        'salir de Bluetooth y volver',
        planCompleted: true,
        expectation: const GoalExpectation(absentText: 'Bluetooth'),
      );
      expect(r.status, GoalStatus.notSatisfied);
    });

    test('sin snapshot final (canal off) → notSatisfied', () async {
      final v = GoalVerifier(executor: _FakeExecutor(null));
      final r = await v.verify(
        'verificar Bluetooth',
        planCompleted: true,
        expectation: const GoalExpectation(visibleText: 'Bluetooth'),
      );
      expect(r.status, GoalStatus.notSatisfied);
      expect(r.reason, contains('canal off'));
    });
  });
}

/// Fake del executor: devuelve un snapshot fijo (o null) sin canal.
class _FakeExecutor implements AgentExecutor {
  _FakeExecutor(this._raw);
  final Map<String, dynamic>? _raw;

  @override
  Future<ResolveOutcome> resolve(NanoSelector selector) async {
    throw UnimplementedError();
  }

  @override
  Future<NanoSnapshot?> snapshot() async =>
      _raw == null ? null : NanoSnapshot.fromRaw(_raw!);

  @override
  Future<AgentExecutionResult> setText(NanoSelector selector, String text) async {
    throw UnimplementedError();
  }

  @override
  Future<AgentExecutionResult> tap(NanoSelector selector) async {
    throw UnimplementedError();
  }
}
