import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nanoai/core/services/nano_runtime_api_provider.dart';
import 'package:nanoai/core/services/runtime_engine.dart';

import 'notification_executor.dart';

/// Provider del executor de notificaciones — INYECTADO (DIP). La sección de UI
/// no construye el servicio; lo consume de aquí. Runtime + engine vía provider.
final notificationExecutorProvider = Provider<NotificationExecutor>((ref) {
  return NotificationExecutor(
    runtime: ref.watch(nanoRuntimeApiProvider),
    engine: ref.read(runtimeEngineProvider.notifier).client,
  );
});
