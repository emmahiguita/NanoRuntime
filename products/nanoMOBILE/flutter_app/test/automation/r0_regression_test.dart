import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/automation/application/automation_coordinator.dart';
import 'package:nanoai/features/automation/benchmark/c14_metrics.dart';
import 'package:nanoai/features/automation/domain/automation_goal.dart';
import 'package:nanoai/features/automation/domain/automation_policy.dart';
import 'package:nanoai/features/automation/domain/automation_result.dart';
import 'package:nanoai/features/automation/engine/execution/agent_tool_dispatcher.dart';
import 'package:nanoai/features/automation/engine/execution/goal_verifier.dart';
import 'package:nanoai/features/automation/engine/execution/tool_registry.dart';
import 'package:nanoai/features/automation/engine/memory/object_memory.dart';
import 'package:nanoai/features/automation/engine/planning/deterministic_catalog.dart';

class _SuccessDispatcher extends AgentToolDispatcher {
  ToolCall? lastCall;

  @override
  Future<ToolOutcome> runToolGuarded(
    ToolCall call, {
    bool humanInitiated = false,
    bool confirmed = false,
  }) async {
    lastCall = call;
    return const ToolOutcome(verdict: PolicyVerdict.allow, feedback: 'ok');
  }
}

void main() {
  test('completedUnverified is not C14 goal success', () async {
    final metrics = <C14Execution>[];
    final dispatcher = _SuccessDispatcher();
    final c = AutomationCoordinator(
      dispatcher: dispatcher,
      mode: () => AgentAutomationMode.autonomous,
      c14Sink: metrics.add,
    );

    final r = await c.execute(
      const AutomationGoal(text: 'volver'),
      plan: const [ToolCall(tool: 'back')],
    );

    expect(r.status, AutomationResultStatus.completedUnverified);
    expect(r.isVerifiedSuccess, isFalse);
    expect(metrics.single.goalSuccess, isFalse);
  });

  test('completedUnverified does not train ObjectMemory', () async {
    final dispatcher = _SuccessDispatcher();
    final c = AutomationCoordinator(
      dispatcher: dispatcher,
      mode: () => AgentAutomationMode.autonomous,
      objectMemory: const NanoObjectMemory(),
    );

    final r = await c.execute(
      const AutomationGoal(text: 'toca Bluetooth'),
      plan: const [ToolCall(tool: 'tap', selector: 'text=Bluetooth')],
    );

    expect(r.status, AutomationResultStatus.completedUnverified);
    expect(
      c.objectMemorySnapshot?.resolve(const UiObjectKey(concept: 'bluetooth')),
      isNull,
    );
  });

  test(
    'ObjectMemory lookup uses target concept, not whole user goal',
    () async {
      final dispatcher = _SuccessDispatcher();
      final memory = const NanoObjectMemory().recordSuccess(
        const UiObjectKey(concept: 'bluetooth'),
        const UiSelectorEvidence(resourceId: 'id_bt'),
      );
      final c = AutomationCoordinator(
        dispatcher: dispatcher,
        mode: () => AgentAutomationMode.autonomous,
        objectMemory: memory,
      );

      await c.execute(
        const AutomationGoal(text: 'abre ajustes y luego bluetooth'),
        plan: const [ToolCall(tool: 'tap', selector: 'text=Bluetooth')],
      );

      expect(dispatcher.lastCall?.selector, 'id=id_bt');
    },
  );

  test('single-step catalog path runs final GoalVerifier', () async {
    var verifies = 0;
    final c = AutomationCoordinator(
      dispatcher: _SuccessDispatcher(),
      mode: () => AgentAutomationMode.autonomous,
      catalog: defaultDeterministicCatalog,
      verifyGoal: (goal, {required planCompleted, expectation}) async {
        verifies++;
        return const GoalVerification(GoalStatus.satisfied, 'verified');
      },
    );

    final r = await c.execute(const AutomationGoal(text: 'abre Bluetooth'));

    expect(verifies, 1);
    expect(r.status, AutomationResultStatus.completed);
  });

  test(
    'Bluetooth status/change request is not intercepted as open flow',
    () async {
      final c = AutomationCoordinator(
        dispatcher: _SuccessDispatcher(),
        mode: () => AgentAutomationMode.autonomous,
        catalog: defaultDeterministicCatalog,
      );

      final status = await c.execute(
        const AutomationGoal(text: 'dime si Bluetooth está activado'),
      );
      final change = await c.execute(
        const AutomationGoal(text: 'activar Bluetooth'),
      );

      expect(status.status, AutomationResultStatus.noPlan);
      expect(change.status, AutomationResultStatus.noPlan);
    },
  );
}
