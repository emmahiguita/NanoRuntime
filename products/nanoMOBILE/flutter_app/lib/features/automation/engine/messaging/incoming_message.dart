/// WA-ID-02 — IncomingMessage: mensaje entrante normalizado con identidad
/// estable y evidencia explícita. Es el contrato UNIVERSAL de mensajería:
/// WhatsApp, WhatsApp Business, Telegram o cualquier app con notificaciones
/// contestables producen el mismo tipo.
///
/// Invariantes:
/// - eventId es DETERMINISTA sobre evidencia factual (package, key,
///   timestamp del mensaje, identidad de remitente y conversación, texto
///   normalizado). Dos publicaciones del MISMO evento producen el MISMO id.
/// - El contenido del mensaje es DATO NO CONFIABLE: jamás se interpreta como
///   autoridad, orden o herramienta.
library;

import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../notifications/notification_object.dart';
import '../../domain/notification_source_fragment.dart';
import 'conversation_key.dart';
import 'reply_capability.dart';

final class IncomingMessage {
  /// Identidad determinista del evento entrante (ver [buildIncomingEventId]).
  final String eventId;

  /// Identidad lógica de la conversación + confianza + evidencia usada.
  final ConversationIdentity conversation;

  /// Key de la StatusBarNotification exacta que produjo este evento.
  final String notificationKey;

  /// Paquete real de la app origen.
  final String packageName;

  /// Remitente visible (Person.name), '' si la app no lo expuso.
  final String sender;

  /// Texto del mensaje individual (MessagingStyle), '' si no existe.
  final String text;

  /// Timestamp del mensaje (MessagingStyle.Message.timestamp). 0 = ausente.
  final int messageTimestamp;

  /// postTime de la notificación que lo entregó.
  final int receivedAt;

  /// Capacidad de respuesta RemoteInput observada, si existe y es usable.
  final ReplyCapabilityRef? replyCapability;

  /// Evidencia cruda conservada (mapa del canal nativo) para auditoría.
  final Map<String, Object?> rawEvidence;
  final List<NotificationSourceFragment> sourceFragments;

  const IncomingMessage({
    required this.eventId,
    required this.conversation,
    required this.notificationKey,
    required this.packageName,
    required this.sender,
    required this.text,
    required this.messageTimestamp,
    required this.receivedAt,
    required this.replyCapability,
    required this.rawEvidence,
    this.sourceFragments = const [],
  });

  bool get hasReplyCapability => replyCapability?.isUsable ?? false;

  /// true si la identidad de la conversación alcanza el umbral de escritura
  /// (evidencia estable de plataforma). Los callers que envían DEBEN exigirlo.
  bool get conversationSafeToWrite => conversation.safeToWrite;

  /// Normaliza una NotificationObject cruda del canal nativo. Nunca falla:
  /// con metadata ausente devuelve campos vacíos y confianza baja.
  factory IncomingMessage.fromNotification(NotificationObject n) {
    final identity = resolveConversationIdentity(n);
    final senderIdentity = [
      n.senderKey,
      n.senderUri,
      n.sender,
    ].firstWhere((s) => s.isNotEmpty, orElse: () => '');
    final eventId = buildIncomingEventId(
      packageName: n.packageName,
      notificationKey: n.key,
      messageTimestamp: n.messageTimestamp,
      postTime: n.postTime,
      senderIdentity: senderIdentity,
      conversationIdentity: identity.key.conversationFingerprint,
      text: n.sourceText,
    );
    return IncomingMessage(
      eventId: eventId,
      conversation: identity,
      notificationKey: n.key,
      packageName: n.packageName,
      sender: n.sender,
      text: n.sourceText,
      messageTimestamp: n.messageTimestamp,
      receivedAt: n.postTime,
      replyCapability: ReplyCapabilityRef.fromNotification(n),
      rawEvidence: const {},
      sourceFragments: n.sourceFragments,
    );
  }

  @override
  String toString() =>
      'IncomingMessage($eventId, ${conversation.key.id}, '
      'from=$sender, safeToWrite=${conversation.safeToWrite})';
}

/// Fingerprint determinista del evento entrante.
///
/// H( package | notificationKey | stamp | senderIdentity |
///    conversationIdentity | normalizedText )
///
/// La clave de notificación SOLA no identifica un mensaje individual: una
/// misma notificación se actualiza con mensajes nuevos. El timestamp del
/// mensaje + identidades + texto normalizado distinguen actualizaciones
/// reales de re-publicaciones del mismo evento.
///
/// B10 — [postTime] entra como fallback SOLO cuando el mensaje no trae
/// timestamp propio (0 = ausente): con timestamp real, el id se mantiene
/// estable frente a re-publicaciones de la misma notificación (renacimiento,
/// replay frío = duplicate correcto); sin él, dos mensajes reales distintos
/// con el mismo texto ("hola" y "hola" del mismo contacto) colisionarían
/// durante todo el TTL de 24 h y el segundo moriría como duplicate.
String buildIncomingEventId({
  required String packageName,
  required String notificationKey,
  required int messageTimestamp,
  required int postTime,
  required String senderIdentity,
  required String conversationIdentity,
  required String text,
}) {
  final stamp = messageTimestamp > 0 ? '$messageTimestamp' : 'post:$postTime';
  final canonical = [
    packageName,
    notificationKey,
    stamp,
    senderIdentity.trim(),
    conversationIdentity.trim(),
    text.trim().toLowerCase(),
  ].join('\u0000');
  final digest = sha256.convert(utf8.encode(canonical)).toString();
  return 'evt:${digest.substring(0, 32)}';
}
