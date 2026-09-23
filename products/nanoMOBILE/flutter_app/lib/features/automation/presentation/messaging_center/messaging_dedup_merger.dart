/// MESSAGING-DEDUP-MERGER — Algoritmo canónico de deduplicación y fusión.
///
/// **QUÉ HACE:**
/// Fusiona el historial persistente de SQLite con las notificaciones vivas de Android
/// en una lista única de conversaciones reales, erradicando chats duplicados y alucinaciones.
///
/// **CÓMO FUNCIONA:**
/// Compara dos conversaciones por paquete + identidad canónica (JID, dígitos de teléfono >= 7,
/// o nombre exacto del contacto). Si coinciden, actualiza el mensaje y hora más reciente.
/// Filtra estrictamente notificaciones del sistema (systemui, phonemanager, android).
///
/// **POR QUÉ:**
/// Cumple con Single Responsibility (SOLID) y la regla de archivos < 200 líneas.
library;

import 'dart:math' as math;
import '../../engine/messaging/conversation_group_resolver.dart';
import '../../engine/messaging/conversation_hub_providers.dart';
import 'messaging_conversation_identity.dart';

abstract final class MessagingDedupMerger {
  /// Paquetes de mensajería reales permitidos (filtra apps del sistema como systemui o phonemanager)
  static const supportedPackages = {
    'com.whatsapp',
    'com.whatsapp.w4b',
    'org.telegram.messenger',
    'org.telegram.plus',
    'com.instagram.android',
    'com.facebook.orca',
    'com.facebook.katana',
    'com.slack',
    'com.google.android.gm',
    'com.twitter.android',
    'com.linkedin.android',
  };

  /// Paquetes del sistema explícitamente vetados para evitar alucinaciones
  static const rejectedSystemPackages = {
    'android',
    'com.android.systemui',
    'com.coloros.phonemanager',
    'com.google.android.googlequicksearchbox',
    'com.oppo.launcher',
  };

  /// Verifica si un paquete pertenece a una aplicación de mensajería real
  static bool isSupportedMessagingApp(String pkg) {
    final cleanPkg = pkg.trim().toLowerCase();
    if (cleanPkg.isEmpty) return false;
    if (rejectedSystemPackages.contains(cleanPkg)) return false;
    if (cleanPkg.startsWith('com.android.') || cleanPkg.startsWith('com.coloros.')) {
      return false;
    }
    return supportedPackages.contains(cleanPkg);
  }

  static String? extractPhoneDigits(String raw) => MessagingConversationIdentity.extractPhoneDigits(raw);
  static String normalizeName(String raw) => MessagingConversationIdentity.normalizeName(raw);

  static bool areSameConversation(ConversationSummaryItem a, ConversationSummaryItem b) =>
      MessagingConversationIdentity.areSame(a, b);

  /// Fusiona dos items de la misma conversación priorizando los datos más recientes y nombres reales
  static ConversationSummaryItem mergeItems(ConversationSummaryItem existing, ConversationSummaryItem incoming) {
    final useIncoming = incoming.lastAtMs >= existing.lastAtMs;
    final latestMessage = useIncoming
        ? (incoming.lastMessage.isNotEmpty ? incoming.lastMessage : existing.lastMessage)
        : (existing.lastMessage.isNotEmpty ? existing.lastMessage : incoming.lastMessage);

    final isGroup = existing.isGroup || incoming.isGroup;

    // WA-GROUP-MERGE: Priorizar título real sobre marcadores genéricos como "Grupo de WhatsApp"
    final groupTitle = (incoming.groupTitle != null && !ConversationGroupResolver.isGenericTitle(incoming.groupTitle))
        ? incoming.groupTitle
        : ((existing.groupTitle != null && !ConversationGroupResolver.isGenericTitle(existing.groupTitle))
              ? existing.groupTitle
              : null);

    final String displayName;
    if (isGroup && groupTitle != null) {
      displayName = groupTitle;
    } else {
      final existingGeneric = ConversationGroupResolver.isGenericTitle(existing.displayName);
      final incomingGeneric = ConversationGroupResolver.isGenericTitle(incoming.displayName);
      if (existingGeneric && !incomingGeneric) {
        displayName = incoming.displayName;
      } else if (!existingGeneric && incomingGeneric) {
        displayName = existing.displayName;
      } else if (MessagingConversationIdentity.isTechnicalName(incoming.displayName) &&
          !MessagingConversationIdentity.isTechnicalName(existing.displayName)) {
        displayName = existing.displayName;
      } else if (MessagingConversationIdentity.isTechnicalName(existing.displayName) &&
          !MessagingConversationIdentity.isTechnicalName(incoming.displayName)) {
        displayName = incoming.displayName;
      } else {
        displayName = useIncoming ? incoming.displayName : existing.displayName;
      }
    }

    if (isGroup && groupTitle != null) {
      ConversationGroupResolver.cacheGroupTitle(existing.conversationId, groupTitle);
      ConversationGroupResolver.cacheGroupTitle(incoming.conversationId, groupTitle);
    }

    // Conserva todas las identidades observadas del mismo chat. La vista y
    // el compositor pueden recuperar así el historial legado que quedó
    // repartido entre un nombre visible y un shortcut/JID de WhatsApp.
    final aliases = <String>{
      ...existing.conversationAliases,
      ...incoming.conversationAliases,
      existing.conversationId,
      incoming.conversationId,
    }.where((id) => id.trim().isNotEmpty).toList(growable: false);

    return ConversationSummaryItem(
      conversationId: existing.conversationId.startsWith('live:') ? incoming.conversationId : existing.conversationId,
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
      activeProductName: existing.activeProductName ?? incoming.activeProductName,
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

  /// Procesa una lista heterogénea y produce un listado deduplicado, ordenado y libre de ruido
  static List<ConversationSummaryItem> deduplicateAndSort(List<ConversationSummaryItem> input) {
    final valid = input.where((item) => isSupportedMessagingApp(item.packageName)).toList();
    final result = <ConversationSummaryItem>[];

    for (final item in valid) {
      var merged = item;
      // Reinicia el recorrido tras cada unión: el elemento fusionado puede
      // enlazar otro alias que antes no coincidía (nombre <-> live <-> JID).
      for (var index = 0; index < result.length;) {
        if (!areSameConversation(result[index], merged)) {
          index++;
          continue;
        }
        merged = mergeItems(result.removeAt(index), merged);
        index = 0;
      }
      result.add(merged);
    }

    result.sort((a, b) => b.lastAtMs.compareTo(a.lastAtMs));
    return result;
  }
}
