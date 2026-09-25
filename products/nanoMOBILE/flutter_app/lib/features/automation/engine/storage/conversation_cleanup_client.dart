/// Cliente mínimo para borrar memoria conversacional durable.
///
/// El canal recibe datos tipados; Kotlin compone el SQL y ejecuta el borrado
/// normalizado junto con el snapshot JSON en una sola transacción.
library;

import 'package:flutter/services.dart';

final class ConversationCleanupClient {
  ConversationCleanupClient._();

  static final instance = ConversationCleanupClient._();
  static const _channel = MethodChannel('com.nanoai/automation_store');

  Future<bool> clear({
    required String scopeId,
    required String memoryJson,
  }) async {
    return await _channel.invokeMethod<bool>('conversationClear', {
          'scopeId': scopeId,
          'memoryJson': memoryJson,
        }) ??
        false;
  }
}
