import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/automation/engine/agent_tool_dispatcher.dart';
import 'package:nanoai/features/automation/engine/experience_cache.dart';
import 'package:nanoai/features/automation/engine/goal_verifier.dart'
    show GoalExpectation, GoalStatus, GoalVerification;
import 'package:nanoai/features/automation/application/automation_coordinator.dart';
import 'package:nanoai/features/automation/domain/automation_goal.dart';
import 'package:nanoai/features/automation/domain/automation_policy.dart';
import 'package:nanoai/features/automation/domain/automation_result.dart';

/// Pruebas del AutomationCoordinator (único dueño del ciclo de ejecución).
///
/// La política de gobernanza y la degradación honesta son lógica NUEVA del
/// coordinator (no del dispatcher); la delegación de plan/tool al dispatcher
/// es un wrapper 1:1 que cubre [agent_tool_dispatcher_test].
void main() {
  AutomationCoordinator coord(AgentAutomationMode mode) => AutomationCoordinator(
        dispatcher: AgentToolDispatcher(),
        mode: () => mode,
      );

  group('AutomationCoordinator · política de gobernanza', () {
    test('manual: todo excepto screen/resolve pide confirmación', () {
      final c = coord(AgentAutomationMode.manual);
      expect(c.requiresConfirmation('tap'), isTrue);
      expect(c.requiresConfirmation('write'), isTrue);
      expect(c.requiresConfirmation('linux.run'), isTrue);
      expect(c.requiresConfirmation('screen'), isFalse);
      expect(c.requiresConfirmation('resolve'), isFalse);
    });

    test('assisted: tap/back/write piden; screen/resolve/read no', () {
      final c = coord(AgentAutomationMode.assisted);
      expect(c.requiresConfirmation('tap'), isTrue);
      expect(c.requiresConfirmation('back'), isTrue);
      expect(c.requiresConfirmation('write'), isTrue);
      expect(c.requiresConfirmation('screen'), isFalse);
      expect(c.requiresConfirmation('resolve'), isFalse);
      expect(c.requiresConfirmation('linux.readFile'), isFalse);
    });

    test('autonomous: solo write pide confirmación', () {
      final c = coord(AgentAutomationMode.autonomous);
      expect(c.requiresConfirmation('write'), isTrue);
      expect(c.requiresConfirmation('tap'), isFalse);
      expect(c.requiresConfirmation('back'), isFalse);
      expect(c.requiresConfirmation('screen'), isFalse);
    });

    test('descripción es legible e incluye el modo', () {
      final c = coord(AgentAutomationMode.autonomous);
      final d = c.confirmationDescription('write');
      expect(d, contains('Autónomo'));
      expect(d, contains('confirmación'));
      expect(d, contains('write'));
    });
  });

  group('AutomationCoordinator · degradación honesta', () {
    test('tryDeterministic devuelve null sin cache/flow (determinista off)',
        () async {
      final c = AutomationCoordinator(
        dispatcher: AgentToolDispatcher(),
        mode: () => AgentAutomationMode.assisted,
      );
      expect(await c.tryDeterministic('abre bluetooth'), isNull);
    });
  });

  group('AutomationCoordinator.execute', () {
    test('sin cache/flow ni plan → noPlan honesto (no inventa éxito)', () async {
      final c = AutomationCoordinator(
        dispatcher: AgentToolDispatcher(),
        mode: () => AgentAutomationMode.assisted,
      );
      final r = await c.execute(const AutomationGoal(text: 'abre bluetooth'));
      expect(r.status, AutomationResultStatus.noPlan);
      expect(r.executionId, isNotEmpty);
      expect(r.reason, contains('Sin flujo'));
    });

    test('usa el executionId provisto por el llamador', () async {
      final c = AutomationCoordinator(
        dispatcher: AgentToolDispatcher(),
        mode: () => AgentAutomationMode.assisted,
      );
      final r = await c.execute(
        const AutomationGoal(text: 'x'),
        options: const AutomationOptions(executionId: 'manual-1'),
      );
      expect(r.executionId, 'manual-1');
    });
  });

  group('AutomationCoordinator · aprendizaje SOUND (bug #1)', () {
    // Nota: runPlanGuarded(const []) devuelve `completed: true` sin tocar el
    // executor (el loop no corre), así que un dispatcher real es seguro aquí.

    test('NO memoriza un plan completado cuyo OBJETIVO no se verificó', () async {
      final cache = ExperienceCache();
      final c = AutomationCoordinator(
        dispatcher: AgentToolDispatcher(),
        mode: () => AgentAutomationMode.autonomous,
        cache: cache,
        verifyGoal: (g, {required planCompleted, expectation}) async =>
            GoalVerification(GoalStatus.notSatisfied, 'no'),
      );
      await c.runPlan(
        const [],
        recordGoal: 'bluetooth',
        expectation: const GoalExpectation(visibleText: 'Bluetooth'),
      );
      expect(cache.planFor('bluetooth'), isNull); // no se aprendió el plan malo
    });

    test('memoriza SOLO cuando el objetivo se verificó satisfecho', () async {
      final cache = ExperienceCache();
      final c = AutomationCoordinator(
        dispatcher: AgentToolDispatcher(),
        mode: () => AgentAutomationMode.autonomous,
        cache: cache,
        verifyGoal: (g, {required planCompleted, expectation}) async =>
            GoalVerification(GoalStatus.satisfied, 'ok'),
      );
      await c.runPlan(
        const [],
        recordGoal: 'bluetooth',
        expectation: const GoalExpectation(visibleText: 'Bluetooth'),
      );
      expect(cache.planFor('bluetooth'), isNotNull);
    });

    test('sin expectativa NO memoriza (no se puede verificar) — sound', () async {
      final cache = ExperienceCache();
      final c = AutomationCoordinator(
        dispatcher: AgentToolDispatcher(),
        mode: () => AgentAutomationMode.autonomous,
        cache: cache,
      );
      await c.runPlan(const [], recordGoal: 'volver');
      expect(cache.planFor('volver'), isNull);
    });
  });
}
