part of 'conversation_detail_sheet.dart';

/// Manages matching Android system notifications with the active conversation.
extension ConversationDetailNotifications on _ConversationDetailSheetState {
  String _cleanName(String raw) {
    raw = ConversationGroupResolver.cleanTitle(raw);
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

    final value = n.toNotificationObject();
    final key = resolveConversationIdentity(value).key;
    if (key.id.isEmpty) return false;
    // Ni nombres ni sufijos numéricos autorizan usar otra notificación.
    final observed = ConversationSummaryItem(
      conversationId: key.id,
      accountFingerprint: key.accountFingerprint,
      packageName: value.packageName,
      displayName: (value.isGroup && value.conversationTitle.isNotEmpty)
          ? value.conversationTitle
          : (value.sender.isNotEmpty ? value.sender : value.title),
      lastMessage: value.interpretableText,
      lastAtMs: value.postTime,
      agentId: widget.item.agentId,
      isGroup: value.isGroup,
      groupTitle: value.isGroup
          ? (value.conversationTitle.isNotEmpty
              ? value.conversationTitle
              : value.title)
          : null,
      notificationKey: value.key,
    );
    return ConversationHistoryResolver.belongsTo(widget.item, observed);
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
