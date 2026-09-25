// device_notification.dart
//
// QUÉ HACE: representa una notificación Android sin mezclar transporte ni IA.
// CÓMO: conserva la evidencia nativa y la adapta a NotificationObject.
// POR QUÉ: una sola frontera tipada evita perder identidad o admitir estados.

import '../engine/notifications/notification_object.dart';

class DeviceNotification {
  final String key;
  final String packageName;
  final String title;
  final String text;
  final DateTime postedAt;
  final bool canReply;
  final bool ongoing;
  final bool isGroup;
  final String sender;
  final String senderKey;
  final String conversationTitle;
  final String conversationId;
  final String shortcutId;
  final String locusId;
  final String accountHint;
  final String messageText;
  final int messageTimestamp;
  final String senderUri;
  final bool isSummary;
  final bool isTruncated;
  final String remoteInputKey;
  final int actionIndex;
  final List<String> actions;
  final List<Map<String, dynamic>> rawMessages;
  final List<String> allowedDataTypes;
  final String notificationCategory;
  final bool hasMessagingStyle;
  final bool isConversationEvent;

  const DeviceNotification({
    required this.key,
    required this.packageName,
    required this.title,
    required this.text,
    required this.postedAt,
    required this.canReply,
    required this.ongoing,
    this.isGroup = false,
    this.sender = '',
    this.senderKey = '',
    this.conversationTitle = '',
    this.conversationId = '',
    this.shortcutId = '',
    this.locusId = '',
    this.accountHint = '',
    this.messageText = '',
    this.messageTimestamp = 0,
    this.senderUri = '',
    this.isSummary = false,
    this.isTruncated = false,
    this.remoteInputKey = '',
    this.actionIndex = -1,
    this.actions = const [],
    this.rawMessages = const [],
    this.allowedDataTypes = const [],
    this.notificationCategory = '',
    this.hasMessagingStyle = true,
    this.isConversationEvent = true,
  });

  /// Convierte el mapa de plataforma sin completar datos ausentes por intuición.
  factory DeviceNotification.fromMap(Map<dynamic, dynamic> map) {
    final epoch = map['postTime'] is num ? (map['postTime'] as num).toInt() : 0;
    return DeviceNotification(
      key: map['key'] as String? ?? '',
      packageName: (map['package'] ?? map['packageName']) as String? ?? '',
      title: map['title'] as String? ?? '',
      text: map['text'] as String? ?? '',
      postedAt: DateTime.fromMillisecondsSinceEpoch(epoch),
      canReply: map['canReply'] as bool? ?? false,
      ongoing: map['ongoing'] as bool? ?? false,
      isGroup: map['isGroup'] as bool? ?? false,
      sender: map['sender'] as String? ?? '',
      senderKey: map['senderKey'] as String? ?? '',
      conversationTitle: map['conversationTitle'] as String? ?? '',
      conversationId: map['conversationId'] as String? ?? '',
      shortcutId: map['shortcutId'] as String? ?? '',
      locusId: map['locusId'] as String? ?? '',
      accountHint: map['accountHint'] as String? ?? '',
      messageText: map['messageText'] as String? ?? '',
      messageTimestamp: map['messageTimestamp'] is num
          ? (map['messageTimestamp'] as num).toInt()
          : 0,
      senderUri: map['senderUri'] as String? ?? '',
      isSummary: map['isSummary'] as bool? ?? false,
      isTruncated: map['isTruncated'] as bool? ?? false,
      remoteInputKey: map['remoteInputKey'] as String? ?? '',
      actionIndex: map['actionIndex'] is num
          ? (map['actionIndex'] as num).toInt()
          : -1,
      actions: _strings(map['actions']),
      rawMessages: ((map['messages'] as List?) ?? const [])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList(growable: false),
      allowedDataTypes: _strings(map['allowedDataTypes']),
      notificationCategory: map['notificationCategory'] as String? ?? '',
      hasMessagingStyle: map['hasMessagingStyle'] != false,
      isConversationEvent: map['isConversationEvent'] != false,
    );
  }

  /// Preserva todos los campos usados por identidad, dedupe y admisión.
  NotificationObject toNotificationObject() => NotificationObject(
    key: key,
    packageName: packageName,
    title: title,
    text: text,
    messageText: messageText.isNotEmpty ? messageText : text,
    messageTimestamp: messageTimestamp > 0
        ? messageTimestamp
        : postedAt.millisecondsSinceEpoch,
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
    postTime: postedAt.millisecondsSinceEpoch,
    canReply: canReply,
    remoteInputKey: remoteInputKey,
    actionIndex: actionIndex,
    actions: actions,
    ongoing: ongoing,
    notificationCategory: notificationCategory,
    hasMessagingStyle: hasMessagingStyle,
    isConversationEvent: isConversationEvent,
  );

  /// Normaliza listas dinámicas que llegan por MethodChannel.
  static List<String> _strings(Object? raw) => ((raw as List?) ?? const [])
      .map((item) => '$item')
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}
