import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nanoai/core/services/runtime_engine.dart';
import 'package:nanoai/features/automation/benchmark/c14_runner.dart';
import 'package:nanoai/main.dart' as app;

/// Benchmark C14-A reproducible de certificación (mismo código que la sección
/// debug de /automation — una sola fuente de verdad).
///
/// Corre en el CPH2557 via `flutter test integration_test/... -d <device>`.
/// El runner (scripts/run_c14_android.ps1|sh) se encarga de: detectar device,
/// instalar APK, lanzar, esperar runtime + GGUF, ejecutar este test, y
/// parsear `C14_REPORT:<json>` del output para imprimir gates + exit code.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // Bug UI REAL encontrado al probar en el CPH2557: home (nano_home_screen) tiene
  // un RenderFlex vertical que desborda 22px. Es COSMÉTICO (franjas amarillas,
  // NO crashea) pero Flutter test lo cuenta como error de render y abortaría el
  // benchmark. Lo ignoramos AQUÍ (para poder correr C14-A); el overflow se
  // reporta aparte como bug de UI de la home, no del módulo automation.
  final prevOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    if (details.toString().contains('overflowed')) return;
    prevOnError?.call(details);
  };

  testWidgets('C14-A automation benchmark', (tester) async {
    app.main();
    // NO pumpAndSettle: la home tiene animaciones continuas (ambient/parallax)
    // que nunca "asientan" y harían timeout. El benchmark usa el container de
    // providers, no la UI — basta un pump acotado para que inicie el boot.
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));

    final ctx = tester.element(find.byType(ProviderScope).first);
    final container = ProviderScope.containerOf(ctx);

    // Asegura runtime + modelo (el preflight lo valida; esto solo espera a que
    // el engine no esté en idle para no correr sobre un runtime a medio subir).
    final engine = container.read(runtimeEngineProvider.notifier);
    await engine.ensureReady();

    final run = await runC14Benchmark(container);

    if (!run.preflight.pass) {
      // Infra/preflight falló: exit code 2 (infra), no 10 tests rojos.
      debugPrint('C14_REPORT:${jsonEncode(run.toJson())}');
      fail('C14 preflight no pasó: ${run.preflight.failCode}');
    }

    final report = run.report!;
    // Imprimo el JSON completo para que el runner lo capture (gates + context).
    debugPrint('C14_REPORT:${jsonEncode(run.toJson())}');
    expect(
      report.gatedPass,
      isTrue,
      reason: 'Gates: '
          '${report.gates.map((g) => '${g.name}=${g.pass}').join(', ')}',
    );
  });
}
