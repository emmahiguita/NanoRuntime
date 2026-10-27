/// Frontera única de persistencia para mensajes canónicos y cobertura histórica.
library;

import 'package:flutter/services.dart';
import 'canonical_message.dart';

final class CanonicalMessageStore {
  static const _channel = MethodChannel('com.nanoai/automation_store');
  Future<void> _writeQueue = Future<void>.value();

  Future<bool> upsert(CanonicalMessage message) {
    final operation = _writeQueue.then((_) async {
      return await _channel.invokeMethod<bool>(
            'canonicalMessageUpsert',
            message.toPlatformMap(),
          ) ??
          false;
    });
    _writeQueue = operation.then<void>((_) {}, onError: (_) {});
    return operation;
  }

  Future<List<CanonicalMessage>> list(
    String conversationId, {
    int limit = 200,
  }) async {
    final rows = await _channel.invokeListMethod<Map<dynamic, dynamic>>(
      'canonicalMessageList',
      {'conversationId': conversationId, 'limit': limit},
    );
    return (rows ?? const [])
        .map(
          (row) =>
              CanonicalMessage.fromPlatformMap(row.cast<String, dynamic>()),
        )
        .toList(growable: false);
  }

  Future<bool> recordCoverage({
    required String conversationId,
    required CanonicalMessageProvider provider,
    required int fromMs,
    required int toMs,
    required bool gapBefore,
  }) async =>
      await _channel.invokeMethod<bool>('conversationCoverageRecord', {
        'conversationId': conversationId,
        'provider': _providerName(provider),
        'fromMs': fromMs,
        'toMs': toMs,
        'gapBefore': gapBefore,
      }) ??
      false;

  Future<List<ConversationCoverage>> coverage(String conversationId) async {
    final rows = await _channel.invokeListMethod<Map<dynamic, dynamic>>(
      'conversationCoverageList',
      {'conversationId': conversationId},
    );
    return (rows ?? const [])
        .map((row) {
          final map = row.cast<String, dynamic>();
          return ConversationCoverage(
            provider: '${map['provider'] ?? ''}',
            fromMs: (map['fromMs'] as num?)?.toInt() ?? 0,
            toMs: (map['toMs'] as num?)?.toInt() ?? 0,
            gapBefore: map['gapBefore'] == true,
          );
        })
        .toList(growable: false);
  }

  static String _providerName(CanonicalMessageProvider provider) =>
      switch (provider) {
        CanonicalMessageProvider.whatsappWeb => 'whatsapp_web',
        CanonicalMessageProvider.androidNotification => 'android_notification',
        CanonicalMessageProvider.metaCloud => 'meta_cloud',
        CanonicalMessageProvider.whatsappMcp => 'whatsapp_mcp',
      };

  /// QUÉ HACE: Lee el último cursor `sequence` confirmado para un stream de sincronización MCP.
  /// CÓMO FUNCIONA: Invoca `syncCursorGet` en `AutomationStoreDb` (Kotlin).
  /// POR QUÉ: Permite reanudar `whatsapp_get_changes` exactamente donde quedó sin duplicar lotes.
  Future<int> getSyncCursor(String stream) async {
    try {
      final map = await _channel.invokeMapMethod<String, dynamic>(
        'syncCursorGet',
        {'stream': stream},
      );
      return (map?['cursorSeq'] as num?)?.toInt() ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// QUÉ HACE: Aplica un lote de mensajes recibidos por `whatsapp_get_changes` y avanza el cursor atómicamente.
  /// CÓMO FUNCIONA: Serializa por `_writeQueue` e invoca `mcpDeltaBatchApply` en una sola transacción SQLite.
  /// POR QUÉ: Garantiza que ningún mensaje ni cursor quede a medias si el proceso se interrumpe.
  Future<bool> applyMcpDeltaBatch({
    required String stream,
    required int nextCursor,
    required int snapshotSeq,
    required List<CanonicalMessage> messages,
  }) {
    final operation = _writeQueue.then((_) async {
      final res = await _channel.invokeMapMethod<String, dynamic>(
        'mcpDeltaBatchApply',
        {
          'stream': stream,
          'nextCursor': nextCursor,
          'snapshotSeq': snapshotSeq,
          'rows': [for (final m in messages) m.toPlatformMap()],
        },
      );
      return res?['ok'] == true;
    });
    _writeQueue = operation.then<void>((_) {}, onError: (_) {});
    return operation;
  }

  /// QUÉ HACE: Obtiene las conversaciones con mensajes entrantes pendientes de respuesta.
  /// CÓMO FUNCIONA: Consulta `pendingConversationsList` en `canonical_messages` dentro de la ventana temporal.
  /// POR QUÉ: Alimenta `<CONTEXTO DEL TURNO>` con hechos reales verificados cuando el usuario pregunta por pendientes.
  Future<List<Map<String, dynamic>>> listPendingConversations({
    int lookbackMs = 7 * 24 * 3600 * 1000,
    int limit = 4,
  }) async {
    try {
      final rows = await _channel.invokeListMethod<Map<dynamic, dynamic>>(
        'pendingConversationsList',
        {'lookbackMs': lookbackMs, 'limit': limit},
      );
      return (rows ?? const [])
          .map((row) => row.cast<String, dynamic>())
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }
}

final canonicalMessageStore = CanonicalMessageStore();

