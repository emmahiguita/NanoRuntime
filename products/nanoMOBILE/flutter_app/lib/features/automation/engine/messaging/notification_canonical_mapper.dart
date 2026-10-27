import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../executors/device_notification.dart';
import '../../domain/notification_attachment_codec.dart';
import 'canonical_message.dart';

/// QUÉ: convierte cada mensaje observado por Android a una fila canónica.
/// CÓMO: conserva tiempo, autor y dirección del MessagingStyle, no del resumen.
/// POR QUÉ: la clave de notificación se reutiliza al llegar nuevos mensajes;
/// usarla como ID descartaba todas las actualizaciones del mismo chat.
abstract final class NotificationCanonicalMapper {
  static List<CanonicalMessage> map(
    DeviceNotification notification,
    String conversationId,
  ) {
    final rows = <CanonicalMessage>[];
    final seen = <String>{};
    final raw = notification.rawMessages;
    final messages = raw.isNotEmpty
        ? raw
        : <Map<String, dynamic>>[
            {
              'messageText': notification.messageText.isNotEmpty
                  ? notification.messageText
                  : notification.text,
              'messageTimestamp': notification.messageTimestamp,
              'sender': notification.sender,
            },
          ];
    for (final message in messages) {
      final attachments = raw.isEmpty
          ? notification.attachments
          : NotificationAttachmentCodec.decode({
              'package': notification.packageName,
              ...message,
            });
      final body = (message['messageText'] ?? message['text'] ?? '')
          .toString()
          .trim();
      if (body.isEmpty) continue;
      final timestamp = (message['messageTimestamp'] as num?)?.toInt() ?? 0;
      final atMs = timestamp > 0
          ? timestamp
          : notification.postedAt.millisecondsSinceEpoch;
      final sender = (message['sender'] ?? notification.sender).toString();
      final direction = message['isSelf'] == true
          ? CanonicalMessageDirection.outbound
          : CanonicalMessageDirection.inbound;
      // La identidad incluye conversación: Personal y Negocio no se mezclan.
      final eventId = sha256
          .convert(
            utf8.encode(
              jsonEncode([conversationId, atMs, direction.name, sender, body]),
            ),
          )
          .toString();
      if (!seen.add(eventId)) continue;
      rows.add(
        CanonicalMessage.observed(
          conversationId: conversationId,
          provider: CanonicalMessageProvider.androidNotification,
          providerMessageId: 'android:$eventId',
          body: body,
          mediaType: attachments.firstOrNull?.type.name ?? '',
          mediaUri: attachments.firstOrNull?.localPath ?? '',
          occurredAtMs: atMs,
          sender: sender.isNotEmpty ? sender : notification.title,
          direction: direction,
          rawMetadata: {
            if (attachments.isNotEmpty)
              'messageAttachments': [
                for (final attachment in attachments)
                  NotificationAttachmentCodec.metadata(attachment),
              ],
            'package': notification.packageName,
            'notificationKey': notification.key,
            'evidenceLevel': 'preview',
            'complete': false,
            'transport': 'android_notification_listener',
            'messageTimestampVerified': timestamp > 0,
            if (notification.accountHint.isNotEmpty)
              'accountId': notification.accountHint,
            if (notification.conversationId.isNotEmpty)
              'sourceChatId': notification.conversationId,
            'truncated':
                message['isTruncated'] == true || notification.isTruncated,
          },
        ),
      );
    }
    return rows;
  }
}
