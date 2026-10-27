/// Adaptador mínimo para retirar una notificación activa de Android.
///
/// No modifica el chat en WhatsApp; expone únicamente la capacidad factual
/// del NotificationListenerService de Nano.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

final class NotificationDismissClient {
  NotificationDismissClient._();

  static final instance = NotificationDismissClient._();
  static const _channel = MethodChannel('com.nanoai/notifications');

  Future<bool> dismiss(String key) async {
    if (key.trim().isEmpty) return false;
    try {
      return await _channel.invokeMethod<bool>('dismiss', {
            'key': key.trim(),
          }) ==
          true;
    } catch (error) {
      debugPrint('[notification-dismiss] error: $error');
      return false;
    }
  }
}
