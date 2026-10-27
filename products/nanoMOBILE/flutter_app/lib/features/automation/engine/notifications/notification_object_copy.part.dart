part of 'notification_object.dart';

/// Copia de contexto: conserva evidencia, destinatario y texto fuente.
extension NotificationObjectCopy on NotificationObject {
  /// Copia inmutable con texto actualizado/enriquecido preservando la identidad.
  NotificationObject withText(
    String newText, {
    List<IncomingAttachment>? attachments,
    List<NotificationSourceFragment>? sourceFragments,
    String? spokenRequest,
  }) => NotificationObject(
    key: key,
    packageName: packageName,
    title: title,
    text: newText,
    messageText: newText,
    originalMessageText: sourceText,
    spokenRequest: spokenRequest ?? this.spokenRequest,
    sourceFragments: sourceFragments ?? this.sourceFragments,
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
}
