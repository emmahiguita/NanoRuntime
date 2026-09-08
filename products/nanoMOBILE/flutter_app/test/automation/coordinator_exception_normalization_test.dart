import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/automation/application/automation_coordinator.dart';
import 'package:nanoai/features/automation/domain/automation_goal.dart';
import 'package:nanoai/features/automation/domain/automation_policy.dart';
import 'package:nanoai/features/automation/domain/automation_result.dart';
import 'package:nanoai/features/automation/engine/execution/agent_tool_dispatcher.dart';
import 'package:nanoai/features/automation/engine/planning/automation_planner.dart';

class _FailingPlanner implements AutomationPlanner {
  @override
  Future<PlannedPlan> plan(String goal) async {
    throw StateError('Simulated unexpected planner crash');
  }
}

void main() {
  test('AutomationCoordinator.execute normalizes unhandled exceptions into failed result', () async {
    final coordinator = AutomationCoordinator(
      dispatcher: AgentToolDispatcher(),
      planner: _FailingPlanner(),
      mode: () => AgentAutomationMode.autonomous,
    );

    // Goal without a pre-computed plan forces planner invocation
    final result = await coordinator.execute(
      const AutomationGoal(text: 'Haz una tarea que fallará en planner'),
    );

    // Invariant: unhandled exception MUST NOT escape; must be normalized to a valid AutomationResult
    expect(result.status, AutomationResultStatus.failed);
    expect(result.reason, contains('[coordinatorException]'));
    expect(result.reason, contains('Simulated unexpected planner crash'));
  });
}
