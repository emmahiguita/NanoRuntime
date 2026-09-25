/// Resumen factual de una conversación mostrado por el centro de mensajería.
library;

import 'conversation_agent.dart';

final class ConversationSummaryItem {
  final String conversationId;
  final String displayName;
  final String packageName;
  final String lastMessage;
  final int lastAtMs;
  final bool hasPendingReply;
  final String? pendingReplyId;
  final String? pendingReplyText;
  final List<String> pendingSuggestions;
  final bool humanOwns;
  final String activeRole;
  final ConversationAgentId agentId;
  final String? activeProductName;
  final int entryCount;
  final String? notificationKey;
  final bool isGroup;
  final String? groupTitle;
  final String? lastSender;
  final List<String> conversationAliases;

  const ConversationSummaryItem({
    required this.conversationId,
    required this.displayName,
    this.packageName = '',
    required this.lastMessage,
    required this.lastAtMs,
    this.hasPendingReply = false,
    this.pendingReplyId,
    this.pendingReplyText,
    this.pendingSuggestions = const [],
    this.humanOwns = false,
    this.activeRole = 'general',
    required this.agentId,
    this.activeProductName,
    this.entryCount = 0,
    this.notificationKey,
    this.isGroup = false,
    this.groupTitle,
    this.lastSender,
    this.conversationAliases = const [],
  });

  String get appLabel => switch (packageName) {
    'com.whatsapp' => 'WhatsApp',
    'com.whatsapp.w4b' => 'WhatsApp Business',
    'org.telegram.messenger' => 'Telegram',
    'com.instagram.android' => 'Instagram',
    _ => 'Mensajería',
  };
}
