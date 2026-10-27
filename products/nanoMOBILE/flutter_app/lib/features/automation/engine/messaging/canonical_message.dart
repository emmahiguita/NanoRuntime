/// Modelo común de mensajes observados por Web, Android, Meta Cloud y WhatsApp MCP.
library;

import 'dart:convert';
import 'package:crypto/crypto.dart';

/// QUÉ HACE: Identifica la fuente autoritativa u observada de cada mensaje canónico.
enum CanonicalMessageProvider {
  whatsappWeb,
  androidNotification,
  metaCloud,
  whatsappMcp,
}

enum CanonicalMessageDirection { inbound, outbound, unknown }

final class CanonicalMessage {
  final String id;
  final String conversationId;
  final CanonicalMessageProvider provider;
  final String providerMessageId;
  final CanonicalMessageDirection direction;
  final String sender;
  final String body;
  final String mediaType;
  final String mediaUri;
  final int occurredAtMs;
  final int observedAtMs;
  final String deliveryState;
  final String fingerprint;
  final Map<String, Object?> rawMetadata;

  const CanonicalMessage({
    required this.id,
    required this.conversationId,
    required this.provider,
    required this.providerMessageId,
    required this.direction,
    required this.sender,
    required this.body,
    required this.mediaType,
    required this.mediaUri,
    required this.occurredAtMs,
    required this.observedAtMs,
    required this.deliveryState,
    required this.fingerprint,
    this.rawMetadata = const {},
  });

  factory CanonicalMessage.observed({
    required String conversationId,
    required CanonicalMessageProvider provider,
    required String body,
    required int occurredAtMs,
    String providerMessageId = '',
    String sender = '',
    String mediaType = '',
    String mediaUri = '',
    CanonicalMessageDirection direction = CanonicalMessageDirection.inbound,
    Map<String, Object?> rawMetadata = const {},
  }) {
    final normalizedBody = body.trim();
    // El instante exacto preserva mensajes legítimos repetidos en pocos segundos.
    final fingerprint = sha256
        .convert(
          utf8.encode(
            [
              conversationId,
              direction.name,
              sender.trim().toLowerCase(),
              normalizedBody,
              mediaType,
              mediaUri.trim(),
              occurredAtMs,
            ].join('|'),
          ),
        )
        .toString();
    final providerKey = provider.name;
    final stableSource = providerMessageId.trim().isNotEmpty
        ? '$providerKey:$conversationId:$providerMessageId'
        : '$providerKey:$conversationId:$fingerprint';
    return CanonicalMessage(
      id: sha256.convert(utf8.encode(stableSource)).toString(),
      conversationId: conversationId,
      provider: provider,
      providerMessageId: providerMessageId.trim(),
      direction: direction,
      sender: sender.trim(),
      body: normalizedBody,
      mediaType: mediaType.trim(),
      mediaUri: mediaUri.trim(),
      occurredAtMs: occurredAtMs,
      observedAtMs: DateTime.now().millisecondsSinceEpoch,
      deliveryState: 'observed',
      fingerprint: fingerprint,
      rawMetadata: rawMetadata,
    );
  }

  Map<String, Object?> toPlatformMap() => {
    'id': id,
    'conversationId': conversationId,
    'provider': switch (provider) {
      CanonicalMessageProvider.whatsappWeb => 'whatsapp_web',
      CanonicalMessageProvider.androidNotification => 'android_notification',
      CanonicalMessageProvider.metaCloud => 'meta_cloud',
      CanonicalMessageProvider.whatsappMcp => 'whatsapp_mcp',
    },
    'providerMessageId': providerMessageId,
    'direction': direction.name,
    'sender': sender,
    'body': body,
    'mediaType': mediaType,
    'mediaUri': mediaUri,
    'occurredAtMs': occurredAtMs,
    'observedAtMs': observedAtMs,
    'deliveryState': deliveryState,
    'fingerprint': fingerprint,
    'rawMetadata': jsonEncode(rawMetadata),
  };

  factory CanonicalMessage.fromPlatformMap(
    Map<String, dynamic> map,
  ) => CanonicalMessage(
    id: '${map['canonical_id'] ?? map['id'] ?? ''}',
    conversationId: '${map['conversation_id'] ?? map['conversationId'] ?? ''}',
    provider: _provider('${map['provider'] ?? ''}'),
    providerMessageId:
        '${map['provider_message_id'] ?? map['providerMessageId'] ?? ''}',
    direction: CanonicalMessageDirection.values.firstWhere(
      (value) => value.name == '${map['direction'] ?? ''}',
      orElse: () => CanonicalMessageDirection.unknown,
    ),
    sender: '${map['sender'] ?? ''}',
    body: '${map['body'] ?? ''}',
    mediaType: '${map['media_type'] ?? map['mediaType'] ?? ''}',
    mediaUri: '${map['media_uri'] ?? map['mediaUri'] ?? ''}',
    occurredAtMs:
        int.tryParse('${map['occurred_at_ms'] ?? map['occurredAtMs'] ?? 0}') ??
        0,
    observedAtMs:
        int.tryParse('${map['observed_at_ms'] ?? map['observedAtMs'] ?? 0}') ??
        0,
    deliveryState: '${map['delivery_state'] ?? map['deliveryState'] ?? ''}',
    fingerprint: '${map['fingerprint'] ?? ''}',
    rawMetadata: _metadata(
      '${map['raw_metadata'] ?? map['rawMetadata'] ?? ''}',
    ),
  );

  static CanonicalMessageProvider _provider(String value) => switch (value) {
    'android_notification' => CanonicalMessageProvider.androidNotification,
    'meta_cloud' => CanonicalMessageProvider.metaCloud,
    'whatsapp_mcp' => CanonicalMessageProvider.whatsappMcp,
    _ => CanonicalMessageProvider.whatsappWeb,
  };

  static Map<String, Object?> _metadata(String value) {
    try {
      return (jsonDecode(value) as Map).cast<String, Object?>();
    } catch (_) {
      return const {};
    }
  }
}

final class ConversationCoverage {
  final String provider;
  final int fromMs;
  final int toMs;
  final bool gapBefore;
  const ConversationCoverage({
    required this.provider,
    required this.fromMs,
    required this.toMs,
    required this.gapBefore,
  });
}
