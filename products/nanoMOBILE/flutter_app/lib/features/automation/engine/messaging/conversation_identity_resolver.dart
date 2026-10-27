/// Resuelve identidad usando únicamente evidencia publicada por Android.
///
/// Orden fuerte: locus, shortcut, Person, JID, conversationId y notificationKey.
/// Nombre/título quedan como etiqueta débil y no autorizan una respuesta.
library;

import '../notifications/notification_object.dart';
import 'conversation_identity_model.dart';
import 'messaging_channel.dart';

final _jidPattern = RegExp(r'[\w\.\-]+@(g\.us|s\.whatsapp\.net)');

ConversationIdentity resolveConversationIdentity(NotificationObject value) =>
    conversationIdentityFor(
      packageName: value.packageName,
      accountHint: value.accountHint,
      locusId: value.locusId,
      shortcutId: value.shortcutId,
      senderKey: value.senderKey,
      conversationId: value.conversationId,
      conversationTitle: value.conversationTitle,
      title: value.title,
      sender: value.sender,
      isGroup: value.isGroup,
      notificationKey: value.key,
    );

/// Mantiene una única política para el pipeline y el centro de mensajes.
ConversationIdentity conversationIdentityFor({
  required String packageName,
  String accountHint = '',
  String locusId = '',
  String shortcutId = '',
  String senderKey = '',
  String conversationId = '',
  String conversationTitle = '',
  String title = '',
  String sender = '',
  bool isGroup = false,
  String notificationKey = '',
}) {
  final key = _keyFactory(packageName, accountHint);

  if (locusId.isNotEmpty) {
    return _resolved(key, 'locus:$locusId', 1, 'locusId');
  }
  if (shortcutId.isNotEmpty) {
    return _resolved(key, 'shortcut:$shortcutId', 0.95, 'shortcutId');
  }
  if (!isGroup && senderKey.isNotEmpty) {
    return _resolved(key, 'person:$senderKey', 0.9, 'senderKey');
  }

  // Un JID encontrado dentro de cualquier campo técnico identifica el chat.
  final jid =
      _jidPattern.firstMatch(notificationKey)?.group(0) ??
      _jidPattern.firstMatch(conversationId)?.group(0) ??
      _jidPattern.firstMatch(shortcutId)?.group(0);
  if (jid != null && jid.isNotEmpty) {
    return _resolved(key, 'jid:$jid', 0.95, 'jid');
  }

  final stableConversationId = conversationId.trim();
  if (stableConversationId.isNotEmpty) {
    return _resolved(key, 'conv:$stableConversationId', 0.85, 'conversationId');
  }

  // Aísla homónimos durante el evento. No demuestra continuidad futura, pero
  // es una identidad factual y evita compartir memoria por nombre visible.
  final stableNotificationKey = notificationKey.trim();
  if (stableNotificationKey.isNotEmpty) {
    return _resolved(
      key,
      'notification:$stableNotificationKey',
      0.8,
      'notificationKey',
    );
  }

  return _weakTitleIdentity(
    key: key,
    conversationTitle: conversationTitle,
    title: title,
    sender: sender,
    isGroup: isGroup,
  );
}

ConversationKey Function(String) _keyFactory(
  String packageName,
  String accountHint,
) {
  final channel = channelForPackage(packageName);
  final account = accountHint.trim();
  return (fingerprint) => ConversationKey(
    channel: channel,
    appPackage: packageName,
    accountFingerprint: account,
    conversationFingerprint: fingerprint,
  );
}

ConversationIdentity _resolved(
  ConversationKey Function(String) key,
  String fingerprint,
  double confidence,
  String evidence,
) => ConversationIdentity(
  key: key(fingerprint),
  confidence: confidence,
  evidenceUsed: {evidence},
);

/// Conserva una etiqueta útil sin presentarla como identidad segura.
ConversationIdentity _weakTitleIdentity({
  required ConversationKey Function(String) key,
  required String conversationTitle,
  required String title,
  required String sender,
  required bool isGroup,
}) {
  final convTitle = conversationTitle.trim();
  final cleanTitle = title.trim();
  final cleanSender = sender.trim();
  final groupName = _groupName(convTitle, cleanTitle, cleanSender, isGroup);
  if (groupName.isNotEmpty) {
    return _resolved(key, 'group:$groupName', 0.35, 'groupTitle');
  }

  final effectiveTitle = convTitle.isNotEmpty
      ? convTitle
      : (cleanTitle.isNotEmpty ? cleanTitle : cleanSender);
  if (effectiveTitle.isEmpty) {
    return ConversationIdentity(
      key: key(''),
      confidence: 0,
      evidenceUsed: const {},
    );
  }
  final context = [
    effectiveTitle,
    if (!isGroup && cleanSender.isNotEmpty && cleanSender != effectiveTitle)
      cleanSender,
  ].join('|');
  return ConversationIdentity(
    key: key('title:$context'),
    confidence: 0.35,
    evidenceUsed: {
      if (convTitle.isNotEmpty) 'conversationTitle',
      if (cleanTitle.isNotEmpty) 'title',
      if (cleanSender.isNotEmpty) 'sender',
    },
  );
}

String _groupName(
  String conversationTitle,
  String title,
  String sender,
  bool isGroup,
) {
  if (!isGroup) return '';
  var value = conversationTitle;
  if (value.isEmpty && title.contains(' @ ')) {
    value = title.split(' @ ').last.trim();
  }
  if (value.isEmpty && title.isNotEmpty && title != sender) value = title;
  if (value.startsWith('@') || value.toLowerCase() == 'whatsapp') return '';
  return value;
}
