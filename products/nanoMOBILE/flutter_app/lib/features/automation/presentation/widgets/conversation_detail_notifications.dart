part of 'conversation_detail_sheet.dart';

/// Manages matching Android system notifications with the active conversation.
extension ConversationDetailNotifications on _ConversationDetailSheetState {
  String get _cleanConvId {
    return canonicalConversationId(widget.item.conversationId);
  }

  String _cleanName(String raw) {
    if (raw.contains('|')) raw = raw.split('|').first;
    if (raw.contains('@g.us') ||
        widget.item.conversationId.contains('@g.us') ||
        widget.item.isGroup) {
      final clean = raw
          .replaceAll(RegExp(r'@g\.us.*'), '')
          .replaceAll('shortcut:', '')
          .replaceAll('conv:', '')
          .trim();
      if (clean.isNotEmpty && !RegExp(r'^\d+$').hasMatch(clean)) {
        return clean;
      }
      return 'Grupo de WhatsApp';
    }
    if (raw.contains('shortcut:') || raw.startsWith('whatsapp/')) {
      final digits = RegExp(r'\d{8,15}').firstMatch(raw)?.group(0);
      return digits != null
          ? 'Contacto WhatsApp ($digits)'
          : 'Chat de WhatsApp';
    }
    return raw;
  }

  bool _notificationMatches(
    DeviceNotification n, {
    bool requireCanReply = false,
  }) {
    if (requireCanReply && !n.canReply) return false;
    if (n.packageName != widget.item.packageName) return false;

    final convId = _cleanConvId;
    final displayName = widget.item.displayName.trim().toLowerCase();
    final notifKey = widget.item.notificationKey?.trim();

    if (notifKey != null && notifKey.isNotEmpty && n.key == notifKey) {
      return true;
    }

    if (convId.isNotEmpty) {
      final nIdentity = resolveConversationIdentity(n.toNotificationObject());
      if (nIdentity.key.id.isNotEmpty &&
          (nIdentity.key.id == convId ||
              nIdentity.key.id.endsWith(convId) ||
              convId.endsWith(nIdentity.key.id))) {
        return true;
      }
      if (n.shortcutId.isNotEmpty &&
          (convId == n.shortcutId ||
              convId.contains(n.shortcutId) ||
              n.shortcutId.contains(convId))) {
        return true;
      }
      if (n.senderKey.isNotEmpty &&
          (convId == n.senderKey ||
              convId.contains(n.senderKey) ||
              n.senderKey.contains(convId))) {
        return true;
      }
      if (n.conversationId.isNotEmpty &&
          (convId == n.conversationId ||
              convId.contains(n.conversationId) ||
              n.conversationId.contains(convId))) {
        return true;
      }
    }

    final targetDigits =
        RegExp(r'\d{7,15}').firstMatch(convId)?.group(0) ??
        RegExp(r'\d{7,15}').firstMatch(displayName)?.group(0);

    if (targetDigits != null && targetDigits.length >= 7) {
      for (final candidate in [
        n.conversationId,
        n.senderKey,
        n.shortcutId,
        n.title,
      ]) {
        final nDigits = RegExp(r'\d{7,15}').firstMatch(candidate)?.group(0);
        if (nDigits != null && nDigits.length >= 7) {
          if (targetDigits == nDigits ||
              targetDigits.endsWith(nDigits) ||
              nDigits.endsWith(targetDigits)) {
            return true;
          }
        }
      }
    }

    final isGeneric =
        displayName.isEmpty ||
        displayName.startsWith('contacto whatsapp') ||
        displayName.startsWith('chat de whatsapp') ||
        displayName == 'whatsapp' ||
        displayName.length < 3;

    if (!isGeneric) {
      final nTitle = n.title.trim().toLowerCase();
      final nSender = n.sender.trim().toLowerCase();
      final nConvTitle = n.conversationTitle.trim().toLowerCase();
      if (nTitle == displayName ||
          (nSender.isNotEmpty && nSender == displayName) ||
          (nConvTitle.isNotEmpty && nConvTitle == displayName)) {
        return true;
      }
    }

    return false;
  }

  DeviceNotification? _findMatchingNotification(
    List<DeviceNotification> list, {
    bool requireCanReply = false,
  }) {
    for (final n in list) {
      if (_notificationMatches(n, requireCanReply: requireCanReply)) return n;
    }
    return null;
  }

  List<DeviceNotification> _findAllMatchingNotifications(
    List<DeviceNotification> list,
  ) {
    return list
        .where((n) => _notificationMatches(n, requireCanReply: false))
        .toList();
  }
}
