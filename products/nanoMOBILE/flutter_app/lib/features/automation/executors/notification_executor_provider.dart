import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    // Sin esto, Sugerir/borrador devolvían silencio con el motor apagado.
    ensureReady: (path) => notifier.ensureReady(modelPath: path),
  );
});
