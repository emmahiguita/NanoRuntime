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
import 'core/theme/design_tokens.dart';
import 'features/automation/headless/automation_headless_runner.dart';
import 'features/automation/application/automation_coordinator_provider.dart'
    show notificationEventRouterProvider, timeTickSchedulerProvider;
import 'features/browser/presentation/widgets/browser_pip_overlay.dart';
import 'features/chat/nano_everywhere/nano_floating_wrapper.dart';

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
    } else if (call.method == 'openOwlHub' || call.method == 'openAssistant') {
      NanoFloatingWrapper.expand();
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
    final settings = ref.watch(settingsProvider);

    final lightTheme = AppTheme.buildTheme(
      NanoLightColors(),
      glassEnabled: settings.glassEnabled,
      glassOpacity: settings.glassOpacity,
      glassClarity: settings.glassClarity,
      glassBlur: settings.glassBlur,
    );

    final darkTheme = AppTheme.buildTheme(
      NanoDarkColors(),
      glassEnabled: settings.glassEnabled,
      glassOpacity: settings.glassOpacity,
      glassClarity: settings.glassClarity,
      glassBlur: settings.glassBlur,
    );

    // Sin wrapper de orientación aquí: rotar forzaba rebuild del MaterialApp
    // completo y producía flicker ("pantalla dañada al voltearse"). La
    // orientación se resuelve DENTRO de cada pantalla vía LayoutBuilder/
    // MediaQuery, que ya manejan portrait/landscape con su propio layout.
    return MaterialApp.router(
      title: 'NanoPlatform',
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      darkTheme: darkTheme,
      // DARK_ONLY: el modo claro queda pendiente hasta completar su diseño.
      themeMode: ThemeMode.dark,
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
        // QUÉ HACE: Envuelve la raíz visual con Overlay.wrap + Material transparente.
        // CÓMO FUNCIONA: Crea un ancestro Overlay y un ancestro Material para todos
        //   los widgets hermanos del Navigator (como BrowserPipOverlay y diálogos).
        // POR QUÉ: Erradica definitivamente el error visual "No Overlay" / "No Material"
        //   (cajas rojas con texto amarillo subrayado) al mostrar controles flotantes.
        return Overlay.wrap(
          child: Material(
            type: MaterialType.transparency,
            child: Stack(
              fit: StackFit.expand,
              children: [
                child ?? const SizedBox.shrink(),
                const BrowserPipOverlay(),
              ],
            ),
          ),
        );
      },
    );
  }
}
