// durable_inbox_entry.dart
//
// QUÉ HACE:
// Registro inmutable de un mensaje entrante ya procesado para garantizar idempotencia.
//
// CÓMO FUNCIONA:
// - Clave compuesta: eventId + conversationId + hash de contenido.
// - Persiste timestamp de recepción para expiración controlada (TTL).
//
// POR QUÉ:
// Evita el procesamiento o respuesta duplicada ante reintentos de red o ráfagas de WhatsApp.

library;

final class DurableInboxEntry {
  final String eventId;
  final String conversationId;
  final String contentHash;
  final DateTime receivedAt;

  const DurableInboxEntry({
    required this.eventId,
    required this.conversationId,
    required this.contentHash,
    required this.receivedAt,
  });

  Map<String, dynamic> toJson() => {
    'eventId': eventId,
    'conversationId': conversationId,
    'contentHash': contentHash,
    'receivedAt': receivedAt.toIso8601String(),
  };

  factory DurableInboxEntry.fromJson(Map<String, dynamic> json) =>
      DurableInboxEntry(
        eventId: (json['eventId'] as String?) ?? '',
        conversationId: (json['conversationId'] as String?) ?? '',
        contentHash: (json['contentHash'] as String?) ?? '',
        receivedAt: DateTime.tryParse((json['receivedAt'] as String?) ?? '') ??
            DateTime.now(),
      );
}
