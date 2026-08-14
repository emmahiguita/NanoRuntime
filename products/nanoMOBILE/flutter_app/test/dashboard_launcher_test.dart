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
import 'package:nanoai/core/theme/design_tokens.dart';
import 'package:nanoai/features/models/application/models_notifier.dart';
import 'package:nanoai/features/models/application/models_provider.dart';
import 'package:nanoai/features/models/application/models_state.dart';
import 'package:nanoai/features/dashboard/presentation/screens/dashboard_screen.dart';

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
        GoRoute(
          path: '/chat',
          builder: (_, __) => const _Placeholder('chat'),
        ),
        GoRoute(
          path: '/models',
          builder: (_, __) => const _Placeholder('models'),
        ),
        ...extraRoutes,
      ],
    );

    Widget app = MaterialApp.router(
      theme: ThemeData(
        brightness: Brightness.dark,
        extensions: [NanoThemeExtension(colors: NanoDarkColors())],
      ),
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
        ramFreeGb: 3.9, ramTotalGb: 8.0, cpuCores: 8,
        tempC: 35, storageTotalGb: 256, storageFreeGb: 209,
        batteryPct: 100, isLive: true,
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
    await tester.tap(find.text('Terminal'));
    await tester.pumpAndSettle();
    expect(find.text('placeholder:terminal'), findsOneWidget);
  });

  testWidgets('Chat navigates to /chat', (tester) async {
    await pumpDashboard(tester);
    await tester.tap(find.text('Chat'));
    await tester.pumpAndSettle();
    expect(find.text('placeholder:chat'), findsOneWidget);
  });

  testWidgets('Modelos navigates to /models', (tester) async {
    await pumpDashboard(tester);
    await tester.tap(find.text('Modelos'));
    await tester.pumpAndSettle();
    // La ruta /models del harness es un placeholder: valida la navegación,
    // no el contenido real de la pantalla.
    expect(find.text('placeholder:models'), findsOneWidget);
  });

  // 5. Valores desconocidos como \u2014
  testWidgets('shows \u2014 for unknown metric values', (tester) async {
    await pumpDashboard(tester);
    expect(find.text('\u2014'), findsWidgets,
        reason: 'missing metrics should display \u2014');
  });

  // 6. 320\u00d7568 sin overflow
  testWidgets('renders at 320x568 without overflow', (tester) async {
    await pumpDashboard(
      tester,
      physicalSize: const Size(960, 1704),
      dashState: const DashboardState(
        ramFreeGb: 3.9, ramTotalGb: 8.0, cpuCores: 8,
        tempC: 35, storageTotalGb: 256, storageFreeGb: 209,
        batteryPct: 100, isLive: true,
      ),
    );
    expect(tester.takeException(), isNull, reason: 'no overflow at 320x568');
    expect(find.text('Terminal'), findsOneWidget);
  });

  // 7. disableAnimations = true
  testWidgets('respects disableAnimations', (tester) async {
    await pumpDashboard(tester, disableAnimations: true);
    expect(find.text('nanoai'), findsOneWidget);
    expect(find.text('Terminal'), findsOneWidget);
  });

  // 8. Identidad nanoai
  testWidgets('shows nanoai identity header', (tester) async {
    await pumpDashboard(tester);
    expect(find.text('nanoai'), findsOneWidget);
    expect(find.text('local intelligence'), findsOneWidget);
  });

  // 9. Valores reales de m\u00e9tricas
  testWidgets('displays real metric values', (tester) async {
    await pumpDashboard(
      tester,
      dashState: const DashboardState(
        ramFreeGb: 3.9, ramTotalGb: 8.0, cpuCores: 8,
        tempC: 35, storageTotalGb: 256, storageFreeGb: 209,
        batteryPct: 100, isLive: true,
      ),
    );
    // Los contadores animan desde 0 hasta el valor real.
    await tester.pumpAndSettle();
    expect(find.text('3.9 GB'), findsOneWidget);
    expect(find.text('8'), findsOneWidget);
    expect(find.text('35 \u00B0C'), findsOneWidget);
    expect(find.text('209 GB'), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);
  });

  // 10. Estado del motor Chat: el launcher no lo muestra (diseño fijo);
  // el estado vive en ChatScreen con el badge LOCAL/DETENIDO.
  testWidgets('shows fixed Chat card subtitle regardless of engine',
      (tester) async {
    await pumpDashboard(
      tester,
      chatState: const ChatState(engineOnline: false),
    );
    expect(find.text('Habla con NanoAI'), findsOneWidget);
    expect(find.text('Motor detenido'), findsNothing);

    await pumpDashboard(
      tester,
      chatState: const ChatState(engineOnline: true),
    );
    expect(find.text('Habla con NanoAI'), findsOneWidget);
  });

  // 11. Transición linuxReady false→true tras initState: el pulso de la
  // card Terminal no debe crashear (bug pantalla roja del inicio).
  testWidgets('linuxReady false->true does not crash pulse', (tester) async {
    Widget build(bool ready) => ProviderScope(
          overrides: [kaliProvider.overrideWithValue(null)],
          child: MaterialApp(
            home: NanoHomeScreen(
              ramFreeGb: null,
              cpuCores: null,
              temperatureC: null,
              storageFreeGb: null,
              batteryPercent: null,
              linuxReady: ready,
              onTerminal: () {},
              onChat: () {},
              onModels: () {},
              onDesktop: () {},
              onSettings: () {},
            ),
          ),
        );

    await tester.pumpWidget(build(false));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Preparando Linux'), findsOneWidget);

    await tester.pumpWidget(build(true));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull,
        reason: 'pulse false->true must not throw');
    expect(find.text('Linux listo'), findsOneWidget);
  });

  // 12. Card Kali con layout propio: no comparte GlassActionCard con la
  // card Terminal (solo Terminal + Chat/Modelos/Escritorio/Ajustes la usan).
  testWidgets('Kali card has its own layout, not GlassActionCard',
      (tester) async {
    await pumpDashboard(tester);
    expect(find.byType(GlassActionCard), findsNWidgets(5),
        reason: 'Terminal + 4 action cards; Kali usa su propio layout');
    expect(find.text('Kali'), findsOneWidget);
  });

  // 13. Estado Kali sin manager: chip honesto NO INICIALIZADO, sin overflow
  // ni siquiera en pantallas angostas (el chip largo es el peor caso).
  testWidgets('Kali shows honest chip when manager is null', (tester) async {
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
          home: NanoHomeScreen(
            ramFreeGb: null,
            cpuCores: null,
            temperatureC: null,
            storageFreeGb: null,
            batteryPercent: null,
            linuxReady: false,
            onTerminal: () {},
            onChat: () {},
            onModels: () {},
            onDesktop: () {},
            onSettings: () {},
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Kali'), findsOneWidget);
    expect(find.text('NO INICIALIZADO'), findsOneWidget);
    expect(tester.takeException(), isNull,
        reason: 'chip largo no debe desbordar a 320 lógicos');
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

    await tester.scrollUntilVisible(
      find.text('Escritorio'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Escritorio'));
    await tester.pumpAndSettle();
    expect(find.text('placeholder:desktop'), findsOneWidget,
        reason: 'atajo debe pasar por /desktop (arranque Xvnc), no VNC directo');
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
