import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart' hide EnginePhase;
import 'package:nanoai/core/theme/app_theme.dart';
import 'package:nanoai/core/services/runtime_engine.dart';
import 'package:nanoai/features/automation/application/automation_coordinator.dart';
import 'package:nanoai/features/automation/application/automation_engine.dart';
import 'package:nanoai/features/automation/application/automation_engine_provider.dart';
import 'package:nanoai/features/automation/domain/automation_goal.dart';
import 'package:nanoai/features/automation/domain/automation_policy.dart';
import 'package:nanoai/features/automation/domain/automation_result.dart';
import 'package:nanoai/features/automation/engine/execution/agent_tool_dispatcher.dart';
import 'package:nanoai/features/automation/ledger/action_ledger.dart';
import 'package:nanoai/features/automation/ledger/action_ledger_provider.dart';
import 'package:nanoai/features/automation/presentation/screens/automation_screen.dart';
import 'package:nanoai/features/automation/presentation/widgets/automation_dashboard.dart'
    show engineStatusProvider;

/// Renders the dashboard (glass/tilt/etc.) and asserts NO overflow/exception
/// at mobile + tablet. Los proveedores pesados se sobrescriben con fakes
/// (engineStatusProvider ligero + engine fake) — el motor real no se arranca.
void main() {
  testWidgets('dashboard renderiza sin overflow (móvil)', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app());
    // NO pumpAndSettle: el glass tiene un AnimationController.repeat() infinito.
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump(const Duration(milliseconds: 250));
    expect(tester.takeException(), isNull);
  });

  testWidgets('dashboard renderiza sin overflow (tablet)', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app());
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump(const Duration(milliseconds: 250));
    expect(tester.takeException(), isNull);
  });

  testWidgets('composer envia un goal y muestra el resultado (flujo real)',
      (tester) async {
    await tester.pumpWidget(_app());
    await tester.pump(const Duration(milliseconds: 250));

    // Escribir + enviar como lo haría un usuario.
    await tester.enterText(find.byType(TextField).first, 'abre Bluetooth');
    await tester.tap(find.byType(FilledButton).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // El fake coord devuelve noPlan → el ActiveExecutionCard muestra el resultado.
    expect(find.textContaining('noPlan'), findsOneWidget);
  });
}

Widget _app() => ProviderScope(
      overrides: _overrides(),
      child: MaterialApp(theme: AppTheme.light, home: const AutomationScreen()),
    );

List<Override> _overrides() => [
      engineStatusProvider.overrideWith(
        (ref) => const EngineStatus(
          port: 8080,
          phase: EnginePhase.ready,
          modelPath: '/data/local/tmp/qwen-q8-fast.gguf',
        ),
      ),
      automationEngineProvider.overrideWith(
        (ref) => AutomationEngine.from(
          _FakeCoordinator(),
          ref.read(actionLedgerProvider),
        ),
      ),
      actionLedgerProvider.overrideWithValue(ActionLedger()),
    ];

class _FakeCoordinator extends AutomationCoordinator {
  _FakeCoordinator()
      : super(
          dispatcher: _DummyDispatcher(),
          mode: () => AgentAutomationMode.autonomous,
        );

  @override
  Future<AutomationResult> execute(
    AutomationGoal goal, {
    List<ToolCall>? plan,
    AutomationOptions? options,
  }) async =>
      const AutomationResult(
        executionId: 'x',
        status: AutomationResultStatus.noPlan,
        reason: 'no plan',
      );
}

class _DummyDispatcher extends AgentToolDispatcher {
  _DummyDispatcher() : super();
}
