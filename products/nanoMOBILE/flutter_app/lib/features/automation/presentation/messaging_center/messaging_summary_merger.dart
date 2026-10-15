/// MESSAGING-SUMMARY-MERGER — Fusión de resúmenes de conversación comprobados.
///
/// **QUÉ HACE:**
/// Combina dos instancias de [ConversationSummaryItem] cuya equivalencia fue validada
/// por [MessagingConversationIdentity], priorizando identificadores canónicos de SQLite.
///
/// **CÓMO FUNCIONA:**
/// Prioriza IDs persistentes sobre temporales (waweb:/live:), conserva el mensaje y hora más
/// reciente, preserva nombres limpios e integra la unión de todos los alias y claves de notificación.
///
/// **POR QUÉ:**
/// Garantiza que al abrir o responder un chat se use el canal nativo comprobable,
/// previniendo desincronizaciones y respetando la regla de código < 200 líneas.
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

    // Priorizar identificador canónico persistente sobre fuentes transitorias (waweb: o live:)
    final existingTransient = MessagingConversationIdentity.isTransientId(
      existing.conversationId,
    );
    final incomingTransient = MessagingConversationIdentity.isTransientId(
      incoming.conversationId,
    );
    String resolvedId;
    if (existingTransient && !incomingTransient) {
      resolvedId = incoming.conversationId;
    } else if (existing.conversationId.startsWith('waweb:') &&
        !incoming.conversationId.startsWith('waweb:')) {
      resolvedId = incoming.conversationId;
    } else {
      resolvedId = existing.conversationId;
    }

    final activeRole =
        (existing.activeRole != 'WhatsApp Web' &&
            existing.activeRole.isNotEmpty)
        ? existing.activeRole
        : incoming.activeRole;

    final notifKey = (existing.notificationKey?.isNotEmpty ?? false)
        ? existing.notificationKey
        : incoming.notificationKey;

    return ConversationSummaryItem(
      conversationId: resolvedId,
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
      activeRole: activeRole,
      agentId: existing.agentId,
      activeProductName:
          existing.activeProductName ?? incoming.activeProductName,
      entryCount: math.max(existing.entryCount, incoming.entryCount),
      notificationKey: notifKey,
      isGroup: isGroup,
      groupTitle: groupTitle,
      lastSender: useIncoming
          ? (incoming.lastSender ?? existing.lastSender)
          : (existing.lastSender ?? incoming.lastSender),
      conversationAliases: aliases,
      accountFingerprint: existing.accountFingerprint.isNotEmpty
          ? existing.accountFingerprint
          : incoming.accountFingerprint,
      messageVerified: existing.messageVerified || incoming.messageVerified,
    );
  }

  static String? _groupTitle(
    ConversationSummaryItem existing,
    ConversationSummaryItem incoming,
  ) {
    final incTitle = ConversationGroupResolver.cleanTitle(
      incoming.groupTitle ?? '',
    );
    if (!ConversationGroupResolver.isGenericTitle(incTitle)) return incTitle;
    final existTitle = ConversationGroupResolver.cleanTitle(
      existing.groupTitle ?? '',
    );
    if (!ConversationGroupResolver.isGenericTitle(existTitle)) {
      return existTitle;
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

    final cleanExisting = ConversationGroupResolver.cleanTitle(
      existing.displayName,
    );
    final cleanIncoming = ConversationGroupResolver.cleanTitle(
      incoming.displayName,
    );
    if (cleanIncoming.isNotEmpty && cleanIncoming == cleanExisting) {
      return cleanIncoming;
    }

    return useIncoming ? incoming.displayName : existing.displayName;
  }
}
