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
      };
}

final canonicalMessageStore = CanonicalMessageStore();
