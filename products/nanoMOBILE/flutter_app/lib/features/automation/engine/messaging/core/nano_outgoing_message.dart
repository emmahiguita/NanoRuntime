// nano_outgoing_message.dart
//
// QUÉ HACE:
// Modelo universal y agnóstico de mensaje saliente producido por Nano Negocio o el Agente.
//
// CÓMO FUNCIONA:
// - Contiene el texto de respuesta, adjuntos y referencias sin detalles de formato de plataforma.
// - El Adapter del canal destino se encarga de traducirlo a su API o RemoteInput nativo.
//
// POR QUÉ:
// Mantiene el principio de separación de responsabilidades y portabilidad multicanal.

library;

final class NanoOutgoingMessage {
  final String id;
  final String conversationId;
  final String text;
  final List<String> attachments; // Paths de archivos locales (PNG, MP4, PDF, etc.)
  final String? replyToMessageId;
  final Map<String, dynamic> metadata;

  const NanoOutgoingMessage({
    required this.id,
    required this.conversationId,
    required this.text,
    this.attachments = const [],
    this.replyToMessageId,
    this.metadata = const {},
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'conversationId': conversationId,
    'text': text,
    'attachments': attachments,
    if (replyToMessageId != null) 'replyToMessageId': replyToMessageId,
    'metadata': metadata,
  };

  factory NanoOutgoingMessage.fromJson(Map<String, dynamic> json) =>
      NanoOutgoingMessage(
        id: (json['id'] as String?) ?? '',
        conversationId: (json['conversationId'] as String?) ?? '',
        text: (json['text'] as String?) ?? '',
        attachments: [
          for (final a in (json['attachments'] as List?) ?? const [])
            if (a is String) a,
        ],
        replyToMessageId: json['replyToMessageId'] as String?,
        metadata: (json['metadata'] as Map?)?.cast<String, dynamic>() ?? const {},
      );
}
