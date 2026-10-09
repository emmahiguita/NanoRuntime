// nano_incoming_message.dart
//
// QUÉ HACE:
// Modelo universal y agnóstico de mensaje entrante para Nano Messaging Core.
//
// CÓMO FUNCIONA:
// - Desacopla completamente el transporte físico (WhatsApp personal, WA Business,
//   Telegram, Instagram, SMS, etc.) del motor de inteligencia y de Nano Negocio.
// - Estandariza remitente, conversación, canal, adjuntos y metadata.
//
// POR QUÉ:
// Regla arquitectónica <channel_agnostic_messaging>: el dominio comercial nunca debe
// depender de tipos específicos de una plataforma de mensajería.

library;

import '../../../domain/messaging_platform.dart';

final class NanoIncomingMessage {
  final String id;
  final MessagingPlatform platform;
  final String accountId; // 'personal', 'business', 'primary', etc.
  final String conversationId;
  final String senderId;
  final String senderDisplayName;
  final String text;
  final List<String> attachments; // Paths o URIs de fotos, videos, audios o documentos
  final DateTime timestamp;
  final Map<String, dynamic> metadata;

  const NanoIncomingMessage({
    required this.id,
    required this.platform,
    this.accountId = 'default',
    required this.conversationId,
    required this.senderId,
    this.senderDisplayName = '',
    required this.text,
    this.attachments = const [],
    required this.timestamp,
    this.metadata = const {},
  });

  bool get hasAttachments => attachments.isNotEmpty;
  bool get isAudio => attachments.any((a) => a.endsWith('.opus') || a.endsWith('.wav') || a.endsWith('.m4a'));
  bool get isImage => attachments.any((a) => a.endsWith('.png') || a.endsWith('.jpg') || a.endsWith('.jpeg'));
  bool get isDocument => attachments.any((a) => a.endsWith('.pdf') || a.endsWith('.doc') || a.endsWith('.docx'));

  Map<String, dynamic> toJson() => {
    'id': id,
    'platform': platform.id,
    'accountId': accountId,
    'conversationId': conversationId,
    'senderId': senderId,
    'senderDisplayName': senderDisplayName,
    'text': text,
    'attachments': attachments,
    'timestamp': timestamp.toIso8601String(),
    'metadata': metadata,
  };

  factory NanoIncomingMessage.fromJson(Map<String, dynamic> json) =>
      NanoIncomingMessage(
        id: (json['id'] as String?) ?? '',
        platform: _parsePlatform(json['platform'] as String?),
        accountId: (json['accountId'] as String?) ?? 'default',
        conversationId: (json['conversationId'] as String?) ?? '',
        senderId: (json['senderId'] as String?) ?? '',
        senderDisplayName: (json['senderDisplayName'] as String?) ?? '',
        text: (json['text'] as String?) ?? '',
        attachments: [
          for (final a in (json['attachments'] as List?) ?? const [])
            if (a is String) a,
        ],
        timestamp: DateTime.tryParse((json['timestamp'] as String?) ?? '') ??
            DateTime.now(),
        metadata: (json['metadata'] as Map?)?.cast<String, dynamic>() ?? const {},
      );

  static MessagingPlatform _parsePlatform(String? id) {
    if (id == null) return MessagingPlatform.whatsapp;
    for (final p in MessagingPlatform.values) {
      if (p.id == id || p.name == id) return p;
    }
    return MessagingPlatform.whatsapp;
  }
}
