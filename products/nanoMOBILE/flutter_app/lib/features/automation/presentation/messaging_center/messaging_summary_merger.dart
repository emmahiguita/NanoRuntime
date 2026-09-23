/// Fusiona resúmenes cuya equivalencia ya fue demostrada.
///
/// No decide identidad: conserva datos recientes, nombres legibles y aliases
/// probados. Separar responsabilidades evita inferencias accidentales.
library;

import 'dart:math' as math;

import '../../engine/messaging/conversation_group_resolver.dart';
import '../../engine/messaging/conversation_hub_providers.dart';
import 'messaging_conversation_identity.dart';

abstract final class MessagingSummaryMerger {
  static ConversationSummaryItem merge(
    ConversationSummaryItem existing,
    ConversationSummaryItem incoming,
  ) {
    final useIncoming = incoming.lastAtMs >= existing.lastAtMs;
    final latestMessage = useIncoming
        ? (incoming.lastMessage.isNotEmpty
              ? incoming.lastMessage
              : existing.lastMessage)
        : (existing.lastMessage.isNotEmpty
              ? existing.lastMessage
              : incoming.lastMessage);
    final isGroup = existing.isGroup || incoming.isGroup;
    final groupTitle = _groupTitle(existing, incoming);
    final displayName = _displayName(
      existing,
      incoming,
      isGroup,
      groupTitle,
      useIncoming,
    );

    if (isGroup && groupTitle != null) {
      // El cache recibe el título solo después de probar identidad.
      ConversationGroupResolver.cacheGroupTitle(
        existing.conversationId,
        groupTitle,
      );
      ConversationGroupResolver.cacheGroupTitle(
        incoming.conversationId,
        groupTitle,
      );
    }

    final aliases = <String>{
      ...existing.conversationAliases,
      ...incoming.conversationAliases,
      existing.conversationId,
      incoming.conversationId,
    }.where((id) => id.trim().isNotEmpty).toList(growable: false);

    return ConversationSummaryItem(
      conversationId: existing.conversationId.startsWith('live:')
          ? incoming.conversationId
          : existing.conversationId,
      displayName: displayName,
      packageName: existing.packageName,
      lastMessage: latestMessage,
      lastAtMs: math.max(existing.lastAtMs, incoming.lastAtMs),
      hasPendingReply: existing.hasPendingReply || incoming.hasPendingReply,
      pendingReplyId: incoming.pendingReplyId ?? existing.pendingReplyId,
      pendingReplyText: incoming.pendingReplyText ?? existing.pendingReplyText,
      pendingSuggestions: incoming.pendingSuggestions.isNotEmpty
          ? incoming.pendingSuggestions
          : existing.pendingSuggestions,
      humanOwns: existing.humanOwns || incoming.humanOwns,
      activeRole: existing.activeRole,
      agentId: existing.agentId,
      activeProductName:
          existing.activeProductName ?? incoming.activeProductName,
      entryCount: math.max(existing.entryCount, incoming.entryCount),
      notificationKey: incoming.notificationKey ?? existing.notificationKey,
      isGroup: isGroup,
      groupTitle: groupTitle,
      lastSender: useIncoming
          ? (incoming.lastSender ?? existing.lastSender)
          : (existing.lastSender ?? incoming.lastSender),
      conversationAliases: aliases,
    );
  }

  static String? _groupTitle(
    ConversationSummaryItem existing,
    ConversationSummaryItem incoming,
  ) {
    if (incoming.groupTitle != null &&
        !ConversationGroupResolver.isGenericTitle(incoming.groupTitle)) {
      return incoming.groupTitle;
    }
    if (existing.groupTitle != null &&
        !ConversationGroupResolver.isGenericTitle(existing.groupTitle)) {
      return existing.groupTitle;
    }
    return null;
  }

  static String _displayName(
    ConversationSummaryItem existing,
    ConversationSummaryItem incoming,
    bool isGroup,
    String? groupTitle,
    bool useIncoming,
  ) {
    if (isGroup && groupTitle != null) return groupTitle;
    final existingGeneric = ConversationGroupResolver.isGenericTitle(
      existing.displayName,
    );
    final incomingGeneric = ConversationGroupResolver.isGenericTitle(
      incoming.displayName,
    );
    if (existingGeneric && !incomingGeneric) return incoming.displayName;
    if (!existingGeneric && incomingGeneric) return existing.displayName;
    if (MessagingConversationIdentity.isTechnicalName(incoming.displayName) &&
        !MessagingConversationIdentity.isTechnicalName(existing.displayName)) {
      return existing.displayName;
    }
    if (MessagingConversationIdentity.isTechnicalName(existing.displayName) &&
        !MessagingConversationIdentity.isTechnicalName(incoming.displayName)) {
      return incoming.displayName;
    }
    return useIncoming ? incoming.displayName : existing.displayName;
  }
}
