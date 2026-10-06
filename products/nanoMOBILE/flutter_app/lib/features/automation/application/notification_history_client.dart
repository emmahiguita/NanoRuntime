import 'package:flutter/services.dart';

/// Lee el historial local que Android captura de notificaciones visibles.
class NotificationHistoryClient {
  static const _channel = MethodChannel('com.nanoai/automation_store');

  /// Devuelve resúmenes persistidos para alimentar el panel de conversaciones.
  Future<List<Map<String, dynamic>>> conversations({int limit = 100}) async {
    final rows = await _channel.invokeListMethod<Map<dynamic, dynamic>>(
      'notificationHistoryList', {'limit': limit},
    );
    return rows?.map((row) => row.cast<String, dynamic>()).toList() ?? const [];
  }

  /// Lee mensajes reales por el hash opaco de conversación, no por su nombre.
  Future<List<Map<String, dynamic>>> messages(String historyId, {int limit = 500}) async {
    final rows = await _channel.invokeListMethod<Map<dynamic, dynamic>>(
      'notificationHistoryMessages', {'historyId': historyId, 'limit': limit},
    );
    return rows?.map((row) => row.cast<String, dynamic>()).toList() ?? const [];
  }
}
