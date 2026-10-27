part of 'notification_object.dart';

// Convierte evidencia nativa y comparte el codec sin inventar identidades.
NotificationObject _notificationFromMap(Map<dynamic, dynamic> raw) {
  final rawSender = '${raw['sender'] ?? ''}'.trim();
  final rawTitle = '${raw['title'] ?? ''}'.trim();
  final effectiveSender = rawSender.isNotEmpty
      ? rawSender
      : (raw['isGroup'] == true ? '' : rawTitle);
  final lowerSender = effectiveSender.toLowerCase();
  final isExplicitSelf =
      lowerSender.isNotEmpty &&
      const {'tú', 'tu', 'you', 'yo', 'me'}.contains(lowerSender);
  return NotificationObject(
    key: '${raw['key'] ?? ''}',
    packageName: '${raw['package'] ?? ''}',
    title: rawTitle,
    text: '${raw['text'] ?? ''}',
    messageText: '${raw['messageText'] ?? ''}',
    messageTimestamp: raw['messageTimestamp'] is num
        ? (raw['messageTimestamp'] as num).toInt()
        : 0,
    sender: effectiveSender,
    senderKey: '${raw['senderKey'] ?? ''}',
    senderUri: '${raw['senderUri'] ?? ''}',
    conversationTitle: '${raw['conversationTitle'] ?? ''}',
    conversationId: '${raw['conversationId'] ?? ''}',
    shortcutId: '${raw['shortcutId'] ?? ''}',
    locusId: '${raw['locusId'] ?? ''}',
    accountHint: '${raw['accountHint'] ?? ''}',
    isGroup: raw['isGroup'] == true,
    isSummary: raw['isSummary'] == true,
    isTruncated: raw['isTruncated'] == true,
    isSelf: raw['isSelf'] == true || isExplicitSelf,
    postTime: raw['postTime'] is num ? (raw['postTime'] as num).toInt() : 0,
    canReply: raw['canReply'] == true,
    remoteInputKey: '${raw['remoteInputKey'] ?? ''}',
    actionIndex: raw['actionIndex'] is num
        ? (raw['actionIndex'] as num).toInt()
        : -1,
    actions: ((raw['actions'] as List?) ?? const [])
        .map((a) => '$a')
        .where((a) => a.isNotEmpty)
        .toList(),
    ongoing: raw['ongoing'] == true,
    notificationCategory: '${raw['notificationCategory'] ?? ''}',
    hasMessagingStyle: raw['hasMessagingStyle'] != false,
    isConversationEvent: raw['isConversationEvent'] != false,
    attachments: NotificationAttachmentCodec.decode(raw),
  );
}
