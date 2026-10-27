import 'package:flutter/services.dart';

/// Lee el historial local que Android captura de notificaciones visibles.
class NotificationHistoryClient {
  static const _channel = MethodChannel('com.nanoai/automation_store');
  final _recentPages = <String, List<Map<String, dynamic>>>{};

  /// Snapshot visual inmediato al reabrir; siempre se revalida con SQLite.
  List<Map<String, dynamic>> cachedPage(String historyId) =>
      _recentPages[historyId] ?? const [];

  /// Lee una página real y devuelve un cursor observable; fallos no equivalen a vacío.
  Future<({List<Map<String, dynamic>> rows, bool hasMore})> page(
    String historyId, {
    Map<String, dynamic>? before,
  }) async {
    final result = await _channel.invokeMapMethod<String, dynamic>(
      'notificationHistoryPage',
      {
        'historyId': historyId,
        // Primera pintura pequeña; las páginas anteriores se piden explícitamente.
        'limit': before == null ? 60 : 200,
        if (before != null) 'beforeMs': before['atMs'],
        if (before != null) 'beforeId': before['eventId'],
      },
    );
    if (result == null ||
        result['rows'] is! List ||
        result['hasMore'] is! bool) {
      throw StateError('La plataforma no confirmó la página de historial');
    }
    final rows = (result['rows'] as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList(growable: false);
    if (before == null) {
      _recentPages.remove(historyId);
      _recentPages[historyId] = rows;
      // Diez chats x 60 filas; no retiene historiales completos ni archivos.
      if (_recentPages.length > 10) {
        _recentPages.remove(_recentPages.keys.first);
      }
    }
    return (rows: rows, hasMore: result['hasMore'] == true);
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
