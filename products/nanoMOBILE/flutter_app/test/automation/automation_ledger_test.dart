import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/automation/engine/agent_tool_dispatcher.dart';
import 'package:nanoai/features/automation/application/automation_coordinator.dart';
import 'package:nanoai/features/automation/domain/automation_policy.dart';
import 'package:nanoai/features/automation/domain/automation_result.dart';
import 'package:nanoai/features/automation/ledger/action_ledger.dart';
import 'package:nanoai/features/automation/ledger/automation_trace.dart';

/// Pruebas del ledger de ejecuciones reales (auditoría / C14).
///
/// El coordinator registra una [AutomationTrace] honesta por cada ejecución
/// (determinista, plan multi-paso, tool suelta) usando el [ActionLedger]
/// inyectado. Se verifica el estado trazado, no un "ok" inventado.
void main() {
  group('ActionLedger', () {
    test('es bounded: expulsa la más antigua', () {
      final ledger = ActionLedger(maxEntries: 3);
      for (var i = 0; i < 5; i++) {
        ledger.record(
          AutomationTrace(
            executionId: 'e$i',
            goal: 'g$i',
            status: AutomationResultStatus.completed,
            summary: 'ok',
            startedAt: DateTime(2024, 1, 1),
            endedAt: DateTime(2024, 1, 1, 0, 0, 1),
          ),
        );
      }
      expect(ledger.size, 3);
      expect(ledger.entries.first.goal, 'g4'); // más reciente primero
      expect(ledger.entries.any((t) => t.goal == 'g0'), isFalse);
    });

    test('forGoal filtra por objetivo exacto', () {
      final ledger = ActionLedger();
      ledger.record(_trace(goal: 'abre bluetooth'));
      ledger.record(_trace(goal: 'abre wifi'));
      expect(ledger.forGoal('abre bluetooth'), hasLength(1));
      expect(ledger.forGoal('azul'), isEmpty);
    });
  });

  group('AutomationCoordinator · registro de trazas', () {
    test('tryDeterministic sin cache/flow no traza (miss honesto)', () async {
      final ledger = ActionLedger();
      final c = AutomationCoordinator(
        dispatcher: AgentToolDispatcher(),
        mode: () => AgentAutomationMode.assisted,
        ledger: ledger,
      );
      expect(await c.tryDeterministic('abre bluetooth'), isNull);
      expect(ledger.size, 0); // miss → no hay ejecución que trazar
    });
  });
}

AutomationTrace _trace({required String goal}) => AutomationTrace(
      executionId: 'e',
      goal: goal,
      status: AutomationResultStatus.completed,
      summary: 'ok',
      startedAt: DateTime(2024, 1, 1),
      endedAt: DateTime(2024, 1, 1, 0, 0, 1),
    );
