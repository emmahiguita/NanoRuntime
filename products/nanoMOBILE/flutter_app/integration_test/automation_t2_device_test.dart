import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nanoai/features/automation/application/automation_coordinator_provider.dart';
import 'package:nanoai/features/automation/engine/agent_dependencies.dart';
import 'package:nanoai/features/automation/engine/planning/message_intent_parser.dart';
import 'package:nanoai/features/automation/engine/orchestration/task_planner.dart';
import 'package:nanoai/main.dart' as app;

/// T2 on-device smoke — valida en el DISPOSITIVO (no en la VM de tests) que:
///   1. el composition root de producción construye (coordinator + orquestador
///      con los resolvers de superficie y observeInputText inyectados);
///   2. el parser de mensaje/respuesta y los templates deterministas de
///      mensajería/búsqueda funcionan con el código REAL compilado;
///   3. el catálogo de apps sale del PackageManager real (grounding factual).
///
/// Corre con: `flutter test integration_test/automation_t2_device_test.dart -d <device>`.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // Mismo guard que C14-A: la home tiene un overflow cosmético de RenderFlex que
  // Flutter test cuenta como error; lo ignoramos para no abortar el smoke.
  final prevOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    if (details.toString().contains('overflowed')) return;
    prevOnError?.call(details);
  };

  testWidgets('automation T2 device smoke', (tester) async {
    app.main();
    // Sin pumpAndSettle: la home tiene animaciones continuas. Pump acotado.
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));

    final ctx = tester.element(find.byType(app.NanoPlatformApp).first);
    final container = ProviderScope.containerOf(ctx);

    // 1. Composition root de producción construye sin crash. Esto ejercita el
    //    TaskOrchestrator cableado con launchApp (args.packageName),
    //    resolveInputSurface / resolveActionSurface / observeInputText.
    final coordinator = container.read(automationCoordinatorProvider);
    expect(coordinator, isNotNull, reason: 'coordinator de producción no null');

    // 2. Parser de mensaje/respuesta (T2.0/T2.8) — código real en dispositivo.
    const parser = MessageIntentParser();
    final reply = parser.parse('responde a Juan que llego a las 8');
    expect(reply.recipient, 'Juan');
    expect(reply.message, 'llego a las 8');
    final msg = parser.parse('escríbele a Juan que llego en 20 minutos');
    expect(msg.recipient, 'Juan');
    expect(msg.message, 'llego en 20 minutos');

    // 3. Templates deterministas (T2.8 mensajería, T2.9 búsqueda) — orden exacto.
    const planner = TaskPlanner();
    final msgPlan = planner.plan('escríbele a Juan: hola')!;
    expect(
      msgPlan.steps.map((s) => s.semanticAction).toList(),
      ['openApp', 'openConversation', 'writeMessage', 'sendMessage'],
    );
    final searchPlan = planner.plan('abre YouTube y busca NanoRuntime')!;
    expect(
      searchPlan.steps.map((s) => s.semanticAction).toList(),
      ['openApp', 'writeQuery', 'submitSearch'],
    );

    // 4. Catálogo de apps real (PackageManager) — grounding factual, no inventado.
    final apps = await container.read(installedAppCatalogProvider).apps;
    expect(apps, isNotEmpty, reason: 'catálogo de apps instaladas no vacío');

    // 5. Snapshot de percepción no debe lanzar (probe best-effort; sin
    //    accesibilidad concedida devuelve null/vacío, nunca crash).
    final snap = await container.read(agentExecutorProvider).snapshot();
    debugPrint('AUTOMATION_T2_SNAPSHOT:${snap?.nodes.length ?? 0}');
  });
}
