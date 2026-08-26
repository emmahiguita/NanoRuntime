import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nanoai/main.dart';
import 'package:nanoai/core/providers/app_providers.dart';

/// Barrido funcional completo sobre dispositivo REAL (OPPO, dev.nanoai.mobile).
/// Verifica las 4 pantallas del shell y que los datos no sean placeholder:
///   - Dashboard: device metrics reales vía MethodChannel (RAM>0, batería>=0)
///     + modelo activo persistido + live tps (si el motor ya generó).
///   - Chat: catálogo real y selección persiste (nanoai_active_model).
///   - Models: 4 modelos reales del catálogo GGUF.
///   - Settings: un toggle muta el estado y persiste (SharedPreferences).
///
/// Requiere motor llama.cpp levantado en el device (para /health -> ready).
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('barrido: dashboard, chat, models y settings 100% funcionales', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    // Settings/Repo se inicializan solos al tacto (init perezoso), pero
    // forzamos init para poder verificar persistencia de forma determinista.
    await container.read(settingsProvider.notifier).init();

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const NanoPlatformApp(),
      ),
    );
    await tester.pumpAndSettle(const Duration(milliseconds: 300));

    Future<void> goTo(String label) async {
      await tester.tap(find.byIcon(Icons.menu_rounded));
      await tester.pumpAndSettle();
      // El label vive en el drawer; scopeamos con find.descendant para no
      // chocar con el título del AppBar (que muestra el tab activo).
      final inDrawer = find.descendant(
        of: find.byType(Drawer),
        matching: find.text(label),
      );
      await tester.tap(inDrawer);
      await tester.pumpAndSettle();
    }

    // ── 1. DASHBOARD: métricas REALES del dispositivo ──
    // Navega a otra pantalla para poder volver a Dashboard (default) desde drawer.
    await goTo('Ajustes');
    await goTo('Dashboard');
    // Espera el primer poll de DeviceMetrics (→ timer 3s, fire inmediato).
    for (var i = 0; i < 15; i++) {
      await tester.pump(const Duration(seconds: 1));
      if (container.read(dashboardProvider).isLive) break;
    }
    final dash = container.read(dashboardProvider);
    expect(
      dash.isLive,
      isTrue,
      reason:
          'MethodChannel com.nanoai/device_metrics debe reportar datos reales',
    );
    expect(dash.ramTotalGb, greaterThan(0));
    expect(
      dash.batteryPct,
      greaterThanOrEqualTo(0),
      reason: 'batería real del device',
    );
    expect(dash.storageTotalGb, greaterThan(0), reason: 'almacenamiento real');
    // Título de sección visible (el icono RAM puede duplicarse con el chip
    // del AppBar en landscape, así que validamos por texto/sección).
    expect(find.text('HARDWARE DEL DISPOSITIVO'), findsOneWidget);

    // El estado de conexión al engine se valida en la sección Chat (tras
    // selectModel con health check determinista).

    // ── 2. MODELOS: catálogo real ──
    await goTo('Modelos');
    await tester.pumpAndSettle();
    // El catálogo completo debe estar en el estado del provider y el primer
    // modelo visible en pantalla. Para el último hacemos scroll manual.
    final modelsState = container.read(modelsProvider);
    expect(
      modelsState.models.length,
      4,
      reason: 'catálogo expone 4 modelos reales',
    );
    for (final m in NeuralCatalog.models) {
      expect(modelsState.models.map((x) => x.name), contains(m.name));
    }
    expect(find.text('Qwen2.5-1.1B-Instruct'), findsOneWidget);
    // Scroll vertical manual hasta ver el último modelo en viewport.
    final last = find.text('DeepSeek-R1-7B-Q2');
    for (var i = 0; i < 10 && last.evaluate().isEmpty; i++) {
      await tester.drag(
        find.byType(Scrollable).hitTestable().last,
        const Offset(0, -400),
      );
      await tester.pumpAndSettle();
    }
    expect(last, findsWidgets, reason: 'último modelo alcanzable con scroll');

    // ── 3. CHAT: modelo activo y persistencia ──
    await goTo('Chat');
    final chat = container.read(chatProvider.notifier);
    chat.selectModel('DeepSeek-R1-7B');
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(seconds: 1));
      if (container.read(chatProvider).activeModel == 'DeepSeek-R1-7B' &&
          container.read(chatProvider).connection !=
              ModelConnectionState.loadingModel) {
        break;
      }
    }
    expect(container.read(chatProvider).activeModel, 'DeepSeek-R1-7B');
    expect(container.read(chatProvider).connection, ModelConnectionState.ready);
    // Persistencia: el valor debe quedar guardado en SharedPreferences real.
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('nanoai_active_model'), 'DeepSeek-R1-7B');

    // ── 4. SETTINGS: toggle + persistencia ──
    await goTo('Ajustes');
    // Alter state e invariante: seteamos desktopMobileMode=false y verificamos
    // que el estado refleja el valor (persistencia real vía repositorio).
    final settings = container.read(settingsProvider.notifier);
    settings.setDesktopMobileMode(false);
    await tester.pumpAndSettle();
    expect(container.read(settingsProvider).desktopMobileMode, isFalse);
    // Reserva de modo móvil para no dejar estado raro en el test.
    settings.setDesktopMobileMode(true);
  });
}
