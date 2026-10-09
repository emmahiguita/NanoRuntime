// durable_outbox_message.dart
//
// QUÉ HACE:
// Representa un mensaje saliente pendiente de entrega garantizada (Durable Outbox).
//
// CÓMO FUNCIONA:
// - Registra ID, canal destino (WhatsApp, Telegram, etc.), payload de texto/media,
//   contador de reintentos y timestamp del próximo intento con backoff exponencial.
//
// POR QUÉ:
// Asegura que ninguna respuesta comercial se pierda por desconexión de red o caída del proceso.

library;

enum OutboxStatus {
  queued,
  sending,
  sent,
  failed,
}

final class DurableOutboxMessage {
  final String id;
  final String conversationId;
  final String channel; // 'whatsapp_direct', 'whatsapp_web', 'meta_api', 'telegram'
  final String text;
  final String? mediaPath;
  final int retryCount;
  final int maxRetries;
  final DateTime nextAttemptAt;
  final OutboxStatus status;
  final String? lastError;

  const DurableOutboxMessage({
    required this.id,
    required this.conversationId,
    required this.channel,
    required this.text,
    this.mediaPath,
    this.retryCount = 0,
    this.maxRetries = 5,
    required this.nextAttemptAt,
    this.status = OutboxStatus.queued,
    this.lastError,
  });

  bool get canRetry => retryCount < maxRetries;

  Duration get nextBackoff =>
      Duration(seconds: (2 * (1 << retryCount)).clamp(2, 60));

  DurableOutboxMessage withNextRetry(String error) {
    final newCount = retryCount + 1;
    final backoff = Duration(seconds: (2 * (1 << newCount)).clamp(2, 60));
    return DurableOutboxMessage(
      id: id,
      conversationId: conversationId,
      channel: channel,
      text: text,
      mediaPath: mediaPath,
      retryCount: newCount,
      maxRetries: maxRetries,
      nextAttemptAt: DateTime.now().add(backoff),
      status: newCount >= maxRetries ? OutboxStatus.failed : OutboxStatus.queued,
      lastError: error,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'conversationId': conversationId,
    'channel': channel,
    'text': text,
    if (mediaPath != null) 'mediaPath': mediaPath,
    'retryCount': retryCount,
    'maxRetries': maxRetries,
    'nextAttemptAt': nextAttemptAt.toIso8601String(),
    'status': status.name,
    if (lastError != null) 'lastError': lastError,
  };

  factory DurableOutboxMessage.fromJson(Map<String, dynamic> json) =>
      DurableOutboxMessage(
        id: (json['id'] as String?) ?? '',
        conversationId: (json['conversationId'] as String?) ?? '',
        channel: (json['channel'] as String?) ?? 'whatsapp_direct',
        text: (json['text'] as String?) ?? '',
        mediaPath: json['mediaPath'] as String?,
        retryCount: (json['retryCount'] as num?)?.toInt() ?? 0,
        maxRetries: (json['maxRetries'] as num?)?.toInt() ?? 5,
        nextAttemptAt: DateTime.tryParse((json['nextAttemptAt'] as String?) ?? '') ??
            DateTime.now(),
        status: _parseStatus(json['status'] as String?),
        lastError: json['lastError'] as String?,
      );

  static OutboxStatus _parseStatus(String? name) {
    if (name == null) return OutboxStatus.queued;
    for (final s in OutboxStatus.values) {
      if (s.name == name) return s;
    }
    return OutboxStatus.queued;
  }
}
