import 'package:flutter/services.dart';

/// Lee el historial local que Android captura de notificaciones visibles.
class NotificationHistoryClient {
  static const _channel = MethodChannel('com.nanoai/automation_store');

  /// Lee una página real y devuelve un cursor observable; fallos no equivalen a vacío.
  Future<({List<Map<String, dynamic>> rows, bool hasMore})> page(
    String historyId, {
    Map<String, dynamic>? before,
  }) async {
    final result = await _channel
        .invokeMapMethod<String, dynamic>('notificationHistoryPage', {
          'historyId': historyId,
          'limit': 200,
          if (before != null) 'beforeMs': before['atMs'],
          if (before != null) 'beforeId': before['eventId'],
        });
    if (result == null ||
        result['rows'] is! List ||
        result['hasMore'] is! bool) {
      throw StateError('La plataforma no confirmó la página de historial');
    }
    return (
      rows: (result['rows'] as List)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList(),
      hasMore: result['hasMore'] == true,
    );
  }

  /// Devuelve resúmenes persistidos para alimentar el panel de conversaciones.
  Future<List<Map<String, dynamic>>> conversations({int limit = 100}) async {
    final rows = await _channel.invokeListMethod<Map<dynamic, dynamic>>(
      'notificationHistoryList',
      {'limit': limit},
    );
    return rows?.map((row) => row.cast<String, dynamic>()).toList() ?? const [];
  }

  /// Lee mensajes reales por el hash opaco de conversación, no por su nombre.
  Future<List<Map<String, dynamic>>> messages(
    String historyId, {
    int limit = 500,
  }) async {
    final rows = await _channel.invokeListMethod<Map<dynamic, dynamic>>(
      'notificationHistoryMessages',
      {'historyId': historyId, 'limit': limit},
    );
    return rows?.map((row) => row.cast<String, dynamic>()).toList() ?? const [];
  }
}
