import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nanoai/core/providers/chat_provider.dart';
import 'package:nanoai/core/providers/settings_provider.dart';
import 'package:nanoai/core/services/nano_runtime_api_provider.dart';
import 'package:nanoai/core/services/runtime_engine.dart';

import 'notification_executor.dart';

/// Provider del executor de notificaciones — INYECTADO (DIP). La sección de UI
/// no construye el servicio; lo consume de aquí. Runtime + engine vía provider.
final notificationExecutorProvider = Provider<NotificationExecutor>((ref) {
  final notifier = ref.read(runtimeEngineProvider.notifier);
  return NotificationExecutor(
    runtime: ref.watch(nanoRuntimeApiProvider),
    engine: notifier.client,
    // SUG-01: arranca el motor si está muerto (idle/failed) antes de generar.
    // El path del modelo activo sale de Chat (mismo patrón que el agente):
    // con null el supervisor arrancaría --no-model y /completion colgaría.
    ensureReady: (_) => notifier.ensureReady(
      modelPath: ref.read(chatProvider).activeModelPath,
    ),
    // WA-PERSONA-01 — estilo del dueño leído EN VIVO al redactar (closures,
    // no watch: el executor es estable y el estilo cambia en cada llamada).
    styleEnabled: () => ref.read(settingsProvider).waStyleEnabled,
    styleText: () => ref.read(settingsProvider).waStyleText,
  );
});
