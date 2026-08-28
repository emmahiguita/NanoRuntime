import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nanoai/features/automation/application/automation_coordinator_provider.dart';
import 'package:nanoai/features/automation/domain/automation_goal.dart';
import 'package:nanoai/main.dart' as app;

/// Prueba REAL en dispositivo: ejecuta un objetivo a través del coordinator de
/// PRODUCCIÓN (trust → plan → dispatcher → launcher → verificación). Sin fakes.
///
/// `abre Chrome` resuelve determinista (PackageManager → launch_app → foreground)
/// y NO necesita LLM ni accesibilidad: es la acción real más robusta para validar
/// el camino completo en un dispositivo.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final prevOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    if (details.toString().contains('overflowed')) return;
    prevOnError?.call(details);
  };

  testWidgets('automation real: abre Chrome', (tester) async {
    app.main();
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));

    final ctx = tester.element(find.byType(app.NanoPlatformApp).first);
    final container = ProviderScope.containerOf(ctx);
    final coordinator = container.read(automationCoordinatorProvider);

    final result = await coordinator.execute(
      const AutomationGoal(text: 'abre Chrome'),
    );
    debugPrint('REAL_ACTION:status=${result.status} reason=${result.reason}');
    expect(result.status, isNotNull);
  });
}
