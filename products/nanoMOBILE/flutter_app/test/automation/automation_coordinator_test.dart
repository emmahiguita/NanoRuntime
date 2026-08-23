import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/automation/engine/agent_tool_dispatcher.dart';
import 'package:nanoai/features/automation/application/automation_coordinator.dart';
import 'package:nanoai/features/automation/domain/automation_policy.dart';

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
}
