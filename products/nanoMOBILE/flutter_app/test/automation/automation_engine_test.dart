import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/automation/application/automation_engine.dart';
import 'package:nanoai/features/automation/application/automation_coordinator.dart';
import 'package:nanoai/features/automation/engine/execution/agent_tool_dispatcher.dart';
import 'package:nanoai/features/automation/domain/automation_goal.dart';
import 'package:nanoai/features/automation/domain/automation_policy.dart';
import 'package:nanoai/features/automation/domain/automation_result.dart';
import 'package:nanoai/features/automation/ledger/action_ledger.dart';
import 'package:nanoai/features/automation/ledger/automation_trace.dart';

/// Pruebas de la facade ABC (pública, legible) del módulo.
void main() {
  group('AutomationEngine (facade pública)', () {
    test('runGoal delega al coordinator y devuelve resultado honesto', () async {
      final ledger = ActionLedger();
      final coord = AutomationCoordinator(
        dispatcher: AgentToolDispatcher(),
        mode: () => AgentAutomationMode.autonomous,
        ledger: ledger,
      );
      final engine = AutomationEngine.from(coord, ledger);
      final r = await engine.runGoal(const AutomationGoal(text: 'abre bluetooth'));
      // Sin cache/planner → noPlan honesto (no inventa éxito).
      expect(r.status, AutomationResultStatus.noPlan);
    });

    test('trace/traceOf exponen el ledger (qué hizo realmente)', () {
      final ledger = ActionLedger();
      ledger.record(
        AutomationTrace(
          executionId: 'e1',
          goal: 'abre Bluetooth',
          status: AutomationResultStatus.completed,
          summary: 'ok',
          startedAt: DateTime(2024, 1, 1),
          endedAt: DateTime(2024, 1, 1, 0, 0, 1),
        ),
      );
      final coord = AutomationCoordinator(
        dispatcher: AgentToolDispatcher(),
        mode: () => AgentAutomationMode.autonomous,
      );
      final engine = AutomationEngine.from(coord, ledger);
      expect(engine.trace(), hasLength(1));
      expect(engine.traceOf('abre Bluetooth'), hasLength(1));
      expect(engine.traceOf('otro'), isEmpty);
    });
  });
}
