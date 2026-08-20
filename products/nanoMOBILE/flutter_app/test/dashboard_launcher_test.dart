import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nanoai/core/providers/dashboard_provider.dart';
import 'package:nanoai/core/providers/chat_provider.dart';
import 'package:nanoai/core/providers/rootfs_provider.dart';
import 'package:nanoai/core/providers/kali_provider.dart';
import 'package:nanoai/core/models/chat_models.dart';
import 'package:nanoai/core/services/rootfs_manager.dart';
import 'package:nanoai/core/services/kali_manager.dart';
import 'package:nanoai/core/theme/app_theme.dart';
import 'package:nanoai/features/models/application/models_notifier.dart';
import 'package:nanoai/features/models/application/models_provider.dart';
import 'package:nanoai/features/models/application/models_state.dart';
import 'package:nanoai/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:nanoai/features/home/nano_home_screen.dart';
import 'package:nanoai/features/home/nano_home_models.dart';

/// Pruebas del launcher NanoAI (DashboardScreen).
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> pumpDashboard(
    WidgetTester tester, {
    DashboardState dashState = const DashboardState(),
    ChatState chatState = const ChatState(),
    ModelsState modelsState = const ModelsState(),
    Size physicalSize = const Size(1080, 1920),
    double devicePixelRatio = 3.0,
    bool disableAnimations = false,
    KaliManager? kali,
    List<RouteBase> extraRoutes = const [],
  }) async {
    tester.view.physicalSize = physicalSize;
    tester.view.devicePixelRatio = devicePixelRatio;
    addTearDown(() {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
    });

    final router = GoRouter(
      initialLocation: '/dashboard',
      routes: [
        GoRoute(
          path: '/dashboard',
          builder: (_, __) => const DashboardScreen(),
        ),
        GoRoute(
          path: '/terminal',
          builder: (_, __) => const _Placeholder('terminal'),
        ),
        GoRoute(path: '/chat', builder: (_, __) => const _Placeholder('chat')),
        GoRoute(
          path: '/models',
          builder: (_, __) => const _Placeholder('models'),
        ),
        ...extraRoutes,
      ],
    );

    // Modo claro real (AppTheme.light): el dashboard es la cara de la app
    // y su glassmorphism vive en el tema claro.
    Widget app = MaterialApp.router(
      theme: AppTheme.light,
      routerConfig: router,
    );

    if (disableAnimations) {
      app = MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: app,
      );
    }

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dashboardProvider.overrideWith(
            (ref) => DashboardNotifier.fixed(ref, dashState),
          ),
          chatProvider.overrideWith(
            (ref) => ChatNotifier.fixed(ref, chatState),
          ),
          modelsProvider.overrideWith(
            (ref) => ModelsNotifier.fixed(ref, modelsState),
          ),
          rootfsProvider.overrideWithValue(RootfsManager()),
          kaliProvider.overrideWithValue(kali),
        ],
        child: app,
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  /// Anima el carousel hasta [page] y deja asentar el scroll.
  ///
  /// `animateToPage` usa un DrivenScrollActivity cuyo `shouldIgnorePointer`
  /// es `true`: durante (y justo después de) la animación el viewport queda
  /// envuelto en un `IgnorePointer` y las cards no reciben taps. La animación
  /// de 300ms termina en el tercer frame (page exacta), pero la transición a
  /// `IdleScrollActivity` (que restaura `shouldIgnorePointer=false`) ocurre en
  /// el frame siguiente. Sin ese pump extra el tap cae sobre el Scrollable,
  /// no sobre la card — reproduce el bug "Terminal funciona, Modelos no".
  Future<void> settleToPage(WidgetTester tester, int page) async {
    final pageView = tester.widget<PageView>(
      find.byKey(const ValueKey('nano-home-carousel')),
    );
    pageView.controller!.animateToPage(
      page,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump(const Duration(milliseconds: 16));
  }

  // 1. Los 3 accesos se renderizan
  testWidgets('renders Terminal, Chat, and Modelos cards', (tester) async {
    await pumpDashboard(tester);
    expect(find.text('Terminal'), findsOneWidget);
    expect(find.text('Chat'), findsOneWidget);
    expect(find.text('Modelos'), findsOneWidget);
  });

  // 2. Ausencia del texto "Dashboard"
  testWidgets('does not show the word "Dashboard"', (tester) async {
    await pumpDashboard(tester);
    expect(find.text('Dashboard'), findsNothing);
    expect(find.textContaining('Dashboard'), findsNothing);
  });

  // 3. Sin m\u00e9tricas duplicadas
  testWidgets('each metric icon appears exactly once', (tester) async {
    await pumpDashboard(
      tester,
      dashState: const DashboardState(
        ramFreeGb: 3.9,
        ramTotalGb: 8.0,
        cpuCores: 8,
        tempC: 35,
        storageTotalGb: 256,
        storageFreeGb: 209,
        batteryPct: 100,
        isLive: true,
      ),
    );
    expect(find.byIcon(Icons.memory_rounded), findsOneWidget);
    expect(find.byIcon(Icons.developer_board_rounded), findsOneWidget);
    expect(find.byIcon(Icons.thermostat_rounded), findsOneWidget);
    expect(find.byIcon(Icons.storage_rounded), findsOneWidget);
    expect(find.byIcon(Icons.battery_full_rounded), findsOneWidget);
  });

  // 4. Navegaci\u00f3n de las 3 tarjetas
  testWidgets('Terminal navigates to /terminal', (tester) async {
    await pumpDashboard(tester);
    await tester.tap(find.byKey(const ValueKey('nano-feature-terminal')));
    await tester.pumpAndSettle();
    expect(find.text('placeholder:terminal'), findsOneWidget);
  });

  testWidgets('Chat navigates to /chat', (tester) async {
    await pumpDashboard(tester);
    // Chat vive en la página 0 del carousel (página inicial = Terminal):
    // anima a la página exacta y deja asentar el scroll antes del tap.
    await settleToPage(tester, 0);
    await tester.tap(find.byKey(const ValueKey('nano-feature-chat')));
    // Tras navegar, la home se desmonta y la reflexión ambiental se libera:
    // pumpAndSettle asienta la transición de ruta.
    await tester.pumpAndSettle();
    expect(find.text('placeholder:chat'), findsOneWidget);
  });

  testWidgets('Modelos navigates to /models', (tester) async {
    await pumpDashboard(tester);
    await settleToPage(tester, 2);
    await tester.tap(find.byKey(const ValueKey('nano-feature-models')));
    // Tras navegar, la home se desmonta y la reflexión ambiental se libera.
    await tester.pumpAndSettle();
    // La ruta /models del harness es un placeholder: valida la navegación,
    // no el contenido real de la pantalla.
    expect(find.text('placeholder:models'), findsOneWidget);
  });

  // 5. Valores desconocidos como \u2014
  testWidgets('shows \u2014 for unknown metric values', (tester) async {
    await pumpDashboard(tester);
    expect(
      find.text('\u2014'),
      findsWidgets,
      reason: 'missing metrics should display \u2014',
    );
  });

  // 6. 320\u00d7568 sin overflow
  testWidgets('renders at 320x568 without overflow', (tester) async {
    await pumpDashboard(
      tester,
      physicalSize: const Size(960, 1704),
      dashState: const DashboardState(
        ramFreeGb: 3.9,
        ramTotalGb: 8.0,
        cpuCores: 8,
        tempC: 35,
        storageTotalGb: 256,
        storageFreeGb: 209,
        batteryPct: 100,
        isLive: true,
      ),
    );
    expect(tester.takeException(), isNull, reason: 'no overflow at 320x568');
    expect(find.text('Terminal'), findsOneWidget);
  });

  // 7. disableAnimations = true
  testWidgets('respects disableAnimations', (tester) async {
    await pumpDashboard(tester, disableAnimations: true);
    expect(find.text('Terminal'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // 8. La identidad global vive en el shell; la home no la duplica.
  testWidgets('does not duplicate the global identity header', (tester) async {
    await pumpDashboard(tester);
    expect(find.text('nanoai'), findsNothing);
    expect(find.text('local intelligence'), findsNothing);
  });

  // 9. Valores reales de m\u00e9tricas
  testWidgets('displays real metric values', (tester) async {
    await pumpDashboard(
      tester,
      dashState: const DashboardState(
        ramFreeGb: 3.9,
        ramTotalGb: 8.0,
        cpuCores: 8,
        tempC: 35,
        storageTotalGb: 256,
        storageFreeGb: 209,
        batteryPct: 100,
        isLive: true,
      ),
    );
    // La reflexión ambiental repite en bucle: pumps finitos en vez de
    // pumpAndSettle (que esperaría la animación infinita).
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.text('3.9 GB'), findsOneWidget);
    expect(find.text('8'), findsOneWidget);
    expect(find.text('35 \u00B0C'), findsOneWidget);
    expect(find.text('209 GB'), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);
  });

  // 10. Subtítulo de la card Chat refleja el estado REAL del motor
  // (diseño honesto: ya no es texto fijo — el motor apagado se anuncia).
  testWidgets('shows honest Chat card subtitle from engine state', (
    tester,
  ) async {
    await pumpDashboard(
      tester,
      chatState: const ChatState(engineOnline: false),
    );
    expect(find.text('Motor apagado — elige modelo'), findsOneWidget);
  });

  // 11. Transición linuxReady false→true tras initState: el pulso de la
  // card Terminal no debe crashear (bug pantalla roja del inicio).
  testWidgets('linuxReady false->true does not crash pulse', (tester) async {
    Widget build(bool ready) => ProviderScope(
      overrides: [kaliProvider.overrideWithValue(null)],
      child: MaterialApp(
        theme: AppTheme.light,
        home: NanoHomeScreen(
          telemetry: const NanoTelemetryData(
            ram: '—',
            cpu: '—',
            temperature: '—',
            freeStorage: '—',
            battery: '—',
          ),
          kaliStatus: ready ? KaliStatus.running : KaliStatus.notInitialized,
          onTerminalTap: () {},
          onChatTap: () {},
          onModelsTap: () {},
          onKaliTap: () {},
        ),
      ),
    );

    await tester.pumpWidget(build(false));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Preparando Linux'), findsOneWidget);

    await tester.pumpWidget(build(true));
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      tester.takeException(),
      isNull,
      reason: 'pulse false->true must not throw',
    );
    expect(find.text('Linux listo'), findsOneWidget);
  });

  // 12. Linux se concentra en el módulo Terminal y queda como telemetría,
  // sin añadir una quinta tarjeta que duplique el acceso.
  testWidgets('Linux is telemetry instead of a duplicated feature card', (
    tester,
  ) async {
    await pumpDashboard(tester);
    expect(
      find.byType(NanoFeatureCard),
      findsNWidgets(3),
      reason: 'carousel: tarjeta central y adyacentes visibles',
    );
    expect(find.text('LINUX'), findsOneWidget);
    expect(find.text('Kali'), findsNothing);
  });

  // 13. Estado Linux sin manager: valor honesto y sin overflow incluso en
  // pantallas angostas.
  testWidgets('Linux shows honest status when manager is null', (tester) async {
    tester.view.physicalSize = const Size(960, 1704);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(() {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [kaliProvider.overrideWithValue(null)],
        child: MaterialApp(
          theme: AppTheme.light,
          home: NanoHomeScreen(
            telemetry: const NanoTelemetryData(
              ram: '—',
              cpu: '—',
              temperature: '—',
              freeStorage: '—',
              battery: '—',
            ),
            kaliStatus: KaliStatus.notInitialized,
            onTerminalTap: () {},
            onChatTap: () {},
            onModelsTap: () {},
            onKaliTap: () {},
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('LINUX'), findsOneWidget);
    expect(find.text('NO INICIALIZADO'), findsOneWidget);
    expect(
      tester.takeException(),
      isNull,
      reason: 'chip largo no debe desbordar a 320 lógicos',
    );
  });

  // 14. Atajo Escritorio: navega a /desktop (flujo completo: instala,
  // arranca Xvnc, espera TCP) — nunca directo a /desktop/vnc sin servidor.
  testWidgets('Desktop shortcut navigates to /desktop', (tester) async {
    await pumpDashboard(
      tester,
      kali: null,
      extraRoutes: [
        GoRoute(
          path: '/desktop',
          builder: (_, __) => const _Placeholder('desktop'),
        ),
        GoRoute(
          path: '/desktop/vnc',
          builder: (_, __) => const _Placeholder('vnc'),
        ),
      ],
    );

    // Escritorio vive en la página 3 (última) del carousel. settleToPage
    // anima a la página exacta y deja asentar el scroll (el DrivenScrollActivity
    // libera el IgnorePointer del viewport solo un frame después de terminar).
    await settleToPage(tester, 3);
    expect(find.text('Escritorio'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('nano-feature-desktop')));
    // Tras navegar, la home se desmonta y la reflexión ambiental se libera.
    await tester.pumpAndSettle();
    expect(
      find.text('placeholder:desktop'),
      findsOneWidget,
      reason: 'atajo debe pasar por /desktop (arranque Xvnc), no VNC directo',
    );
    expect(find.text('placeholder:vnc'), findsNothing);
  });
}

class _Placeholder extends StatelessWidget {
  final String name;
  const _Placeholder(this.name);

  @override
  Widget build(BuildContext context) =>
      Scaffold(body: Text('placeholder:$name'));
}
