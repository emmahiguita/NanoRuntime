/// A14.6 — NotificationObject: representación tipada de una notificación activa
/// como CAPACIDAD del sistema (Notification Capability Graph). Cada notificación
/// de Android con acción RemoteInput es una capacidad de respuesta genérica
/// (no "WhatsAppReply" ni por app): el mismo contrato vale para Telegram,
/// Signal, Discord, Slack, Teams o cualquier app que publique una notificación
/// de mensajería contestable.
///
library;

import '../../domain/incoming_attachment.dart';
import '../../domain/notification_attachment_codec.dart';
import '../../domain/notification_source_fragment.dart';

part 'notification_object_mapper.part.dart';
part 'notification_object_copy.part.dart';

/// Objeto de notificación con identidad/estructura real extraída del
/// MessagingStyle de Android. Campos vacíos = no expuesto por la app origen
/// (honesto, nunca se inventa un sender ni un texto).
final class NotificationObject {
  final String key;
  final String packageName;
  final String title;
  final String text;

  /// Texto del mensaje individual (MessagingStyle), si existe.
  final String messageText;

  /// El enriquecimiento cambia el contexto, nunca la identidad del evento.
  final String originalMessageText;

  /// Solo una transcripción real puede sustituir la voz por texto de intención.
  final String spokenRequest;
  final List<NotificationSourceFragment> sourceFragments;

  /// Timestamp del mensaje individual (MessagingStyle.Message.timestamp).
  /// 0 = la app origen no lo expuso.
  final int messageTimestamp;

  /// Remitente (Person.name del último mensaje), si existe.
  final String sender;

  /// Identidad estable del remitente (Person.key), si existe.
  final String senderKey;

  /// URI del remitente (Person.uri, p. ej. tel:), si existe.
  final String senderUri;

  final String conversationTitle;
  final String conversationId;

  /// Shortcut de conversación publicado por la app origen, si existe.
  final String shortcutId;

  /// Locus de conversación (API 29+), si la app lo publicó.
  final String locusId;

  /// Hint de cuenta/dispositivo (EXTRA_SUB_TEXT), si existe.
  final String accountHint;

  /// true si la notificación viene de una conversación grupal.
  final bool isGroup;

  /// true si es una notificación agregada (FLAG_GROUP_SUMMARY).
  final bool isSummary;
  final bool isTruncated;

  /// true si el mensaje proviene del propio usuario (isSelf en MessagingStyle).
  final bool isSelf;

  final int postTime;
  final bool canReply;
  final String remoteInputKey;

  /// Índice de la acción de reply dentro de `actions`. -1 = sin reply.
  final int actionIndex;

  final List<String> actions;
  final bool ongoing;

  /// Evidencia nativa que distingue chats reales de estados/avisos del sistema.
  final String notificationCategory;
  final bool hasMessagingStyle;
  final bool isConversationEvent;
  final List<IncomingAttachment> attachments;

  const NotificationObject({
    required this.key,
    required this.packageName,
    required this.title,
    required this.text,
    required this.messageText,
    this.originalMessageText = '',
    this.spokenRequest = '',
    this.sourceFragments = const [],
    required this.messageTimestamp,
    required this.sender,
    required this.senderKey,
    required this.senderUri,
    required this.conversationTitle,
    required this.conversationId,
    required this.shortcutId,
    required this.locusId,
    required this.accountHint,
    required this.isGroup,
    required this.isSummary,
    this.isTruncated = false,
    this.isSelf = false,
    required this.postTime,
    required this.canReply,
    required this.remoteInputKey,
    required this.actionIndex,
    required this.actions,
    required this.ongoing,
    this.notificationCategory = '',
    this.hasMessagingStyle = true,
    this.isConversationEvent = true,
    this.attachments = const [],
  });

  /// Expand Android's visible message history using each original event's
  /// identity, rather than presenting only the last notification update.
  static List<NotificationObject> eventsFromMap(Map<dynamic, dynamic> raw) {
    final messages = raw['messages'];
    if (messages is! List || messages.isEmpty) {
      return [NotificationObject.fromMap(raw)];
    }
    return [
      for (final m in messages)
        if (m is Map)
          NotificationObject.fromMap({
            ...raw,
            // Un contenedor no puede prestar su último archivo a todo el replay.
            'audioPath': '', 'imagePath': '', 'videoPath': '', 'pdfPath': '',
            ...m,
            if ((m['sender'] == null || '${m['sender']}'.trim().isEmpty) &&
                raw['sender'] != null &&
                '${raw['sender']}'.trim().isNotEmpty)
              'sender': raw['sender'],
          }),
    ];
  }

  factory NotificationObject.fromMap(Map<dynamic, dynamic> raw) =>
      _notificationFromMap(raw);

  /// Identidad legible para el modelo/planner: "Juan C. (WhatsApp)".
  String get identity {
    final who = sender.isNotEmpty ? sender : conversationTitle;
    final label = who.isNotEmpty ? who : title;
    return '$label ($packageName)';
  }

  /// Texto más relevante para interpretar: mensaje individual > texto grande.
  String get interpretableText => messageText.isNotEmpty ? messageText : text;

  /// Mantiene deduplicación y autoría aunque se añada OCR al contexto.
  String get sourceText =>
      originalMessageText.isEmpty ? interpretableText : originalMessageText;

  /// Solo una transcripción del evento actual sustituye al texto para intención.
  String get requestText => spokenRequest.isEmpty ? sourceText : spokenRequest;

  /// true si esta notificación se refiere a [recipient] (coincidencia en
  /// sender/conversationTitle/title). Fuente única de matching por remitente:
  /// la usan NotificationCandidateProvider (reply) y TaskOrchestrator (T2.8,
  /// derivar la app de mensajería), evitando duplicar la lógica.
  bool matchesRecipient(String recipient) {
    final needle = recipient.trim().toLowerCase();
    if (needle.isEmpty) return false;
    final hay = '$sender $conversationTitle $title'.toLowerCase();
    return hay.contains(needle);
  }

  /// Copia inmutable con texto actualizado/enriquecido preservando la identidad.
  NotificationObject withText(
    String newText, {
    List<IncomingAttachment>? attachments,
  }) => NotificationObject(
    key: key,
    packageName: packageName,
    title: title,
    text: newText,
    messageText: newText,
    messageTimestamp: messageTimestamp,
    sender: sender,
    senderKey: senderKey,
    senderUri: senderUri,
    conversationTitle: conversationTitle,
    conversationId: conversationId,
    shortcutId: shortcutId,
    locusId: locusId,
    accountHint: accountHint,
    isGroup: isGroup,
    isSummary: isSummary,
    isTruncated: isTruncated,
    isSelf: isSelf,
    postTime: postTime,
    canReply: canReply,
    remoteInputKey: remoteInputKey,
    actionIndex: actionIndex,
    actions: actions,
    ongoing: ongoing,
    notificationCategory: notificationCategory,
    hasMessagingStyle: hasMessagingStyle,
    isConversationEvent: isConversationEvent,
    attachments: attachments ?? this.attachments,
  );

  @override
  String toString() =>
      'NotificationObject($identity, canReply=$canReply, group=$isGroup)';
}
