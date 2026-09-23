part of 'conversation_detail_sheet.dart';

/// Reconstruye evidencia de identidad para un chat guardado cuando Android ya
/// no conserva su notificación activa. No inventa otro ID ni duplica el ID
/// canónico completo dentro de `conversationId`.
NotificationObject notificationFromConversationSummary(ConversationSummaryItem item) {
  final canonical = canonicalConversationId(item.conversationId);
  final parts = canonical.split('/');
  var fingerprint = parts.length >= 4 ? parts.skip(3).join('/') : canonical;

  // Repara IDs creados por versiones anteriores que envolvieron dos veces la
  // clave completa (`conv:whatsapp/com.whatsapp/...`).
  if (fingerprint.startsWith('conv:')) {
    final nested = fingerprint.substring('conv:'.length).split('/');
    if (nested.length >= 4 && nested[1] == item.packageName) {
      fingerprint = nested.skip(3).join('/');
    }
  }

  final identity = <String, Object?>{};
  void assign(String prefix, String field) {
    if (fingerprint.startsWith(prefix)) {
      identity[field] = fingerprint.substring(prefix.length);
    }
  }

  assign('locus:', 'locusId');
  assign('shortcut:', 'shortcutId');
  assign('person:', 'senderKey');
  assign('conv:', 'conversationId');
  assign('jid:', 'conversationId');
  assign('group:', 'conversationTitle');
  if (identity.isEmpty && fingerprint.contains('@')) {
    identity['conversationId'] = fingerprint;
  }

  return NotificationObject.fromMap({
    'key': 'hub_$canonical',
    'package': item.packageName,
    'title': item.displayName,
    'text': item.lastMessage,
    'messageText': item.lastMessage,
    'sender': item.lastSender ?? item.displayName,
    'postTime': item.lastAtMs,
    'messageTimestamp': item.lastAtMs,
    'isGroup': item.isGroup,
    'canReply': false,
    ...identity,
  });
}
