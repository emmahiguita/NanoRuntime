part of 'messaging_live_notifications_provider.dart';

/// Adapta solo mensajes admitidos y conserva su evidencia para el filtro del panel.
ConversationSummaryItem? _buildSummary(
  DeviceNotification notif,
  ConversationOwnershipStore ownershipStore,
  SettingsState settings,
  int now,
) {
  if (!MessagingDedupMerger.isSupportedMessagingApp(notif.packageName)) {
    return null;
  }

  final notifObj = notif.toNotificationObject();
  if (WhatsAppStatusClassifier.shouldIgnoreFromChatHub(notifObj)) {
    return null;
  }

  final identity = resolveConversationIdentity(notifObj);
  final rawConvKey = notif.conversationId.isNotEmpty
      ? notif.conversationId
      : (notif.shortcutId.isNotEmpty
            ? notif.shortcutId
            : '${notif.packageName}:${notif.title}');
  final convKey = identity.key.id.isNotEmpty ? identity.key.id : rawConvKey;
  final isGroup = ConversationGroupResolver.isGroup(
    convId: rawConvKey,
    isGroupFlag: notif.isGroup,
    rawTitle: notif.title.isNotEmpty ? notif.title : null,
    conversationTitle: notif.conversationTitle.isNotEmpty
        ? notif.conversationTitle
        : null,
    shortcutId: notif.shortcutId.isNotEmpty ? notif.shortcutId : null,
  );
  final groupInfo = isGroup
      ? ConversationGroupResolver.resolveGroupInfo(
          convId: rawConvKey,
          conversationTitle: notif.conversationTitle.isNotEmpty
              ? notif.conversationTitle
              : null,
          title: notif.title.isNotEmpty ? notif.title : null,
          sender: notif.sender.isNotEmpty ? notif.sender : null,
        )
      : null;

  final groupTitle = groupInfo?.groupTitle;
  final displayName = isGroup
      ? (groupTitle ?? 'Grupo de WhatsApp')
      : (notif.sender.isNotEmpty
            ? notif.sender
            : (notif.title.isNotEmpty ? notif.title : 'Chat'));
  final lastSender = isGroup
      ? (groupInfo?.lastSender.isNotEmpty == true
            ? groupInfo!.lastSender
            : (notif.sender.isNotEmpty ? notif.sender : null))
      : (notif.sender.isNotEmpty ? notif.sender : null);
  final agentId = notif.packageName == 'com.whatsapp.w4b'
      ? ConversationAgentId.business
      : ConversationAgentId.personal;
  final messageText = notif.messageText.isNotEmpty
      ? notif.messageText
      : (notif.text.isNotEmpty ? notif.text : '');

  final lowerName = displayName.trim().toLowerCase();
  final lowerMsg = messageText.trim().toLowerCase();
  if (displayName == '0' ||
      lowerName == 'actualizaciones de estado' ||
      lowerName == 'status updates' ||
      lowerName == 'actualizaciones' ||
      lowerName == 'novedades' ||
      lowerName.contains('comprobando si hay') ||
      lowerName.contains('buscando mensajes nuevos')) {
    return null;
  }
  if (lowerMsg.contains('le gustó tu estado') ||
      lowerMsg.contains('le gusta tu estado') ||
      lowerMsg.contains('dio me gusta a tu estado') ||
      lowerMsg.contains('reacted to your status') ||
      lowerMsg.contains('replied to your status') ||
      lowerMsg.contains('comprobando si hay') ||
      lowerMsg.contains('buscando mensajes nuevos')) {
    return null;
  }

  final atMs = notif.messageTimestamp > 0
      ? notif.messageTimestamp
      : (notif.postedAt.millisecondsSinceEpoch > 0
            ? notif.postedAt.millisecondsSinceEpoch
            : now);

  return ConversationSummaryItem(
    conversationId: 'live:$convKey',
    displayName: displayName,
    packageName: notif.packageName,
    lastMessage: messageText,
    lastAtMs: atMs,
    hasPendingReply: false,
    humanOwns: ConversationOwnershipPolicy.humanOwns(
      targetContactsMode: settings.waTargetContactsMode,
      ownership: ConversationOwnershipPolicy.ownershipForNotification(
        store: ownershipStore,
        conversationId: convKey,
        notification: notifObj,
        isGroup: isGroup,
      ),
    ),
    agentId: agentId,
    entryCount: 1,
    notificationKey: notif.key,
    messageVerified: notif.isConversationEvent,
    isGroup: isGroup,
    groupTitle: groupTitle,
    lastSender: lastSender,
  );
}
