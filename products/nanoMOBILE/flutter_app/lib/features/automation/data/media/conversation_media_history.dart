import '../../domain/incoming_attachment.dart';
import '../../domain/notification_attachment_codec.dart';
import '../../engine/messaging/canonical_message.dart';
import '../../engine/messaging/canonical_message_store.dart';
import '../../engine/messaging/conversation_key.dart';
import '../../engine/notifications/notification_object.dart';

/// QUÉ: permite referencias a un adjunto anterior del mismo chat tras reiniciar.
/// CÓMO: relee metadatos nativos de mensajes canónicos; jamás interpreta rutas del texto.
/// POR QUÉ: «ese PDF» debe consultar el archivo observado, no inventar recuerdos.
abstract final class ConversationMediaHistory {
  static Future<List<IncomingAttachment>> referenced(
    NotificationObject notification,
  ) async {
    final text = notification.interpretableText.toLowerCase();
    if (!RegExp(
      r'\b(?:esa? |este? |la |el |del |sobre |anterior|mand[eé]|envi[eé]).*(?:foto|imagen|archivo|pdf|documento|audio)|\b(?:foto|imagen|archivo|pdf|documento|audio)\b.*\b(?:anterior|mandaste|enviaste)\b',
    ).hasMatch(text)) {
      return [];
    }
    try {
      final scope = resolveConversationIdentity(notification).key.id;
      final rows = await canonicalMessageStore
          .list(scope, limit: 12)
          .timeout(const Duration(milliseconds: 1200));
      final stamp = notification.messageTimestamp > 0
          ? notification.messageTimestamp
          : notification.postTime;
      final wantsPdf = text.contains('pdf') || text.contains('documento');
      final wantsImage = text.contains('foto') || text.contains('imagen');
      for (final row in rows.reversed) {
        if (row.conversationId != scope ||
            row.provider != CanonicalMessageProvider.androidNotification ||
            row.direction != CanonicalMessageDirection.inbound ||
            row.occurredAtMs >= stamp ||
            row.rawMetadata['package'] != notification.packageName) {
          continue;
        }
        final attachments =
            NotificationAttachmentCodec.fromMetadata(
                  row.rawMetadata['messageAttachments'],
                )
                .where(
                  (a) => wantsPdf
                      ? a.type == AttachmentType.document
                      : wantsImage
                      ? a.type == AttachmentType.image
                      : true,
                )
                .toList();
        if (attachments.isNotEmpty) return attachments;
      }
    } catch (_) {
      /* Memoria no disponible: no convertir ausencia en contenido. */
    }
    return [];
  }
}
