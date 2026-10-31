import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/widgets/error/nano_error_widget_builder.dart';
import 'core/linux/linux_init.dart';
import 'core/providers/app_providers.dart';
import 'core/router/app_router.dart';
import 'core/services/boot_orchestrator.dart';
import 'core/services/nano_runtime_api.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/nano_motion.dart';
import 'core/theme/design_tokens.dart';
import 'core/widgets/navigation/nano_universal_drawer_overlay.dart';
import 'features/automation/headless/automation_headless_runner.dart';
import 'features/automation/application/automation_coordinator_provider.dart'
    show notificationEventRouterProvider, timeTickSchedulerProvider;
import 'features/automation/engine/scheduling/notification_event_router.dart';
import 'features/browser/presentation/widgets/browser_pip_overlay.dart';
import 'features/chat/nano_everywhere/nano_floating_wrapper.dart';
import 'features/chat/nano_everywhere/nano_external_surface.dart';
import 'features/browser/application/browser_audio_service_initializer.dart';
import 'features/browser/application/browser_audio_handler.dart';

part 'nano_platform_app.dart';

/// Channel used by MainActivity to navigate when the app is already running
/// and Android opens the app from system settings.
const _kNavChannel = MethodChannel('com.nanoai/navigation');

void Function(String prompt)? _onExternalPromptReceived;

late final BrowserAudioHandler audioHandler;

Future<void> main() async {
  final binding = WidgetsFlutterBinding.ensureInitialized();
  ErrorWidget.builder = buildNanoErrorWidget;

  // WA-PROD-01: el MISMO entrypoint sirve a los dos engines. El engine
  // headless del AutomationRuntimeService no tiene Activity: en vez de
  // runApp() corre el bootstrap de automatización (barrera de stores →
  // drenado del inbox durable → RulePipeline intacto).
  // QUÉ: separa engine visible y engine de automatización sin temporizadores.
  // CÓMO: el servicio nativo asigna una ruta privada antes de ejecutar Dart.
  // POR QUÉ: consultar un canal aquí retrasaba el primer frame hasta 1.5 s.
  final initialRoute = binding.platformDispatcher.defaultRouteName;
  if (initialRoute == '/automation-headless') {
    await runAutomationHeadless();
    return;
  }

  final container = ProviderContainer();

  // Crear el controlador local de inmediato; registrar el servicio del SO no
  // debe impedir que Flutter dibuje la primera pantalla.
  audioHandler = BrowserAudioHandler(container);

  AppRouter.init(initialRoute == '/' ? null : initialRoute);

  initializeLinuxDistributions();

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const NanoPlatformApp(),
    ),
  );
  _listenSystemNavigation();
  // El audio es opcional al inicio y se conecta después del primer frame.
  unawaited(initializeBrowserAudioService(audioHandler));
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
