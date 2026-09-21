import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/linux/linux_init.dart';
import 'core/providers/app_providers.dart';
import 'core/router/app_router.dart';
import 'core/services/boot_orchestrator.dart';
import 'core/services/nano_runtime_api.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/nano_motion.dart';
import 'features/automation/headless/automation_headless_runner.dart';
import 'features/automation/application/automation_coordinator_provider.dart'
    show notificationEventRouterProvider, timeTickSchedulerProvider;
import 'features/browser/presentation/widgets/browser_pip_overlay.dart';
import 'features/browser/presentation/widgets/nano_floating_owl_hub_sheet.dart';

/// Channel used by MainActivity to navigate when the app is already running
/// and Android opens the app from system settings.
const _kNavChannel = MethodChannel('com.nanoai/navigation');

void Function(String prompt)? _onExternalPromptReceived;

Future<void> main() async {
  final binding = WidgetsFlutterBinding.ensureInitialized();

  // WA-PROD-01: el MISMO entrypoint sirve a los dos engines. El engine
  // headless del AutomationRuntimeService no tiene Activity: en vez de
  // runApp() corre el bootstrap de automatización (barrera de stores →
  // drenado del inbox durable → RulePipeline intacto).
  if (await isHeadlessAutomationEngine()) {
    await runAutomationHeadless();
    return;
  }

  final initialRoute = binding.platformDispatcher.defaultRouteName;
  AppRouter.init(initialRoute == '/' ? null : initialRoute);

  initializeLinuxDistributions();

  runApp(const ProviderScope(child: NanoPlatformApp()));
  _listenSystemNavigation();
}

/// Warm start: app is already alive and Android asks it to open Settings.
void _listenSystemNavigation() {
  _kNavChannel.setMethodCallHandler((call) async {
    if (call.method == 'openSettings') {
      AppRouter.router.go('/settings');
    } else if (call.method == 'openOwlHub') {
      final ctx = AppRouter.rootNavigatorKey.currentContext;
      if (ctx != null) {
        NanoFloatingOwlHubSheet.show(ctx);
      }
    } else if (call.method == 'navigate') {
      final route = call.arguments as String?;
      if (route != null && route.isNotEmpty) {
        AppRouter.router.go(route);
      }
    } else if (call.method == 'submitPrompt') {
      final prompt = call.arguments as String?;
      if (prompt != null && prompt.trim().isNotEmpty) {
        _onExternalPromptReceived?.call(prompt.trim());
      }
    }
  });
}

class NanoPlatformApp extends ConsumerStatefulWidget {
  const NanoPlatformApp({super.key});

  @override
  ConsumerState<NanoPlatformApp> createState() => _NanoPlatformAppState();
}

class _NanoPlatformAppState extends ConsumerState<NanoPlatformApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _onExternalPromptReceived = (prompt) {
      AppRouter.router.go('/chat');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(chatProvider.notifier).send(prompt);
      });
    };
    // Habilitar inmersión total sticky: oculta la barra de estado (wifi, hora,
    // batería) para aprovechar al 100% la pantalla sin barras del sistema.
    _applyImmersiveMode();
    // Cargar settings persistidos (tema, password VNC, límites del motor)
    // ANTES del primer frame. Sin esto, un arranque en frío ignora el
    // password VNC guardado y el visor/launcher arrancan Xvnc sin auth.
    unawaited(ref.read(settingsProvider.notifier).init());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _applyImmersiveMode();
      unawaited(BootOrchestrator().run());
      // Pide los permisos runtime que falten (micrófono, medios y, en Android
      // 13+, POST_NOTIFICATIONS) tras el primer frame. Solo muestra diálogos de
      // los que faltan; los ya concedidos no molestan.
      unawaited(NanoRuntimeApi.instance.requestRuntimePermissions());
      // WA-UI-LIFECYCLE-01 — bootstrap del router de eventos y scheduler
      // mientras Nano esté abierta en foreground (UI path).
      ref.read(notificationEventRouterProvider);
      ref.read(timeTickSchedulerProvider);
    });
  }

  @override
  void dispose() {
    _onExternalPromptReceived = null;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _applyImmersiveMode();
    }
  }

  void _applyImmersiveMode() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);

    // Sin wrapper de orientación aquí: rotar forzaba rebuild del MaterialApp
    // completo y producía flicker ("pantalla dañada al voltearse"). La
    // orientación se resuelve DENTRO de cada pantalla vía LayoutBuilder/
    // MediaQuery, que ya manejan portrait/landscape con su propio layout.
    return MaterialApp.router(
      title: 'NanoPlatform',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      themeAnimationDuration:
          WidgetsBinding
              .instance
              .platformDispatcher
              .accessibilityFeatures
              .disableAnimations
          ? Duration.zero
          : NanoMotionDurations.standard,
      themeAnimationCurve: NanoMotionCurves.standardDecel,
      routerConfig: AppRouter.router,
      builder: (context, child) {
        // OVERLAY-FIX-01: No encapsular en un OverlayEntry artificial aquí.
        // MaterialApp.router ya provee su propio Overlay nativo con el Navigator.
        // Un Overlay manual adicional en el builder destruye el lookup de Overlay.of(context)
        // en diálogos, tooltips y menús, generando la caja roja "No Overlay".
        return Stack(
          fit: StackFit.expand,
          children: [
            child ?? const SizedBox.shrink(),
            const BrowserPipOverlay(),
          ],
        );
      },
    );
  }
}
