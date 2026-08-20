import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show MethodChannel;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/linux/linux_init.dart';
import 'core/providers/app_providers.dart';
import 'core/router/app_router.dart';
import 'core/services/boot_orchestrator.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/design_tokens.dart';
import 'core/theme/adaptive_theme.dart';
import 'core/widgets/nano_shader_host.dart';

/// Channel used by MainActivity to navigate when the app is already running
/// and Android opens the app from system settings.
const _kNavChannel = MethodChannel('com.nanoai/navigation');

void main() {
  final binding = WidgetsFlutterBinding.ensureInitialized();
  final initialRoute = binding.platformDispatcher.defaultRouteName;
  AppRouter.init(initialRoute == '/' ? null : initialRoute);

  // Inicializar registry de distribuciones Linux y precarga de shaders GPU
  initializeLinuxDistributions();
  unawaited(NanoShaderHost.preload());

  runApp(const ProviderScope(child: NanoPlatformApp()));
  _listenSystemNavigation();
}

/// Warm start: app is already alive and Android asks it to open Settings.
void _listenSystemNavigation() {
  _kNavChannel.setMethodCallHandler((call) async {
    if (call.method == 'openSettings') {
      AppRouter.router.go('/settings');
    }
  });
}

class NanoPlatformApp extends ConsumerStatefulWidget {
  const NanoPlatformApp({super.key});

  @override
  ConsumerState<NanoPlatformApp> createState() => _NanoPlatformAppState();
}

class _NanoPlatformAppState extends ConsumerState<NanoPlatformApp> {
  @override
  void initState() {
    super.initState();
    // Cargar settings persistidos (tema, password VNC, límites del motor)
    // ANTES del primer frame. Sin esto, un arranque en frío ignora el
    // password VNC guardado y el visor/launcher arrancan Xvnc sin auth.
    unawaited(ref.read(settingsProvider.notifier).init());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(BootOrchestrator().run());
    });
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
      routerConfig: AppRouter.router,
      // Animación de transición de tema suave (dark↔light).
      builder: (context, child) {
        return AnimatedSwitcher(
          duration: AdaptiveTheme.getThemeTransitionDuration(context),
          switchInCurve: NanoCurves.easeInOut,
          switchOutCurve: NanoCurves.easeInOut,
          transitionBuilder: (child, animation) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
          child: child,
        );
      },
    );
  }
}
