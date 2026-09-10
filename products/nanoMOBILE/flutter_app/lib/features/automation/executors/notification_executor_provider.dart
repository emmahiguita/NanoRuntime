import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nanoai/core/services/nano_runtime_api_provider.dart';
import 'package:nanoai/features/automation/application/automation_coordinator_provider.dart'
    show conversationReplyComposerProvider;

import 'notification_executor.dart';

/// Provider del executor de notificaciones — inyecta el compositor conversacional
/// canónico único para toda la aplicación (Cerebro Único).
final notificationExecutorProvider = Provider<NotificationExecutor>((ref) {
  return NotificationExecutor(
    runtime: ref.watch(nanoRuntimeApiProvider),
    composer: ref.watch(conversationReplyComposerProvider),
  );
});
