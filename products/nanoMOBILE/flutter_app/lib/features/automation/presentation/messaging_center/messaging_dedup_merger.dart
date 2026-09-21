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
import '../../engine/messaging/conversation_hub_providers.dart';

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
    if (cleanPkg.startsWith('com.android.') || cleanPkg.startsWith('com.coloros.')) return false;
    return supportedPackages.contains(cleanPkg);
  }

  /// Extrae dígitos de teléfono de 7 a 15 números para matching
  static String? extractPhoneDigits(String raw) {
    final match = RegExp(r'\d{7,15}').firstMatch(raw);
    return match?.group(0);
  }

  /// Normaliza el nombre visible del contacto
  static String normalizeName(String raw) {
    final lower = raw.trim().toLowerCase();
    if (lower.isEmpty ||
        lower.startsWith('contacto whatsapp') ||
        lower.startsWith('chat de whatsapp') ||
        lower == 'whatsapp' ||
        lower.length < 2) {
      return '';
    }
    return lower;
  }

  /// Determina si dos items corresponden a la misma conversación humana
  static bool areSameConversation(ConversationSummaryItem a, ConversationSummaryItem b) {
    if (a.packageName != b.packageName) return false;

    // 1. Coincidencia por conversationId limpio
    final idA = a.conversationId.replaceFirst('live:', '').trim();
    final idB = b.conversationId.replaceFirst('live:', '').trim();
    if (idA.isNotEmpty && idA == idB) return true;

    // 2. Coincidencia por dígitos telefónicos
    final digitsA = extractPhoneDigits(idA) ?? extractPhoneDigits(a.displayName);
    final digitsB = extractPhoneDigits(idB) ?? extractPhoneDigits(b.displayName);
    if (digitsA != null && digitsB != null && digitsA.length >= 7 && digitsB.length >= 7) {
      if (digitsA == digitsB || digitsA.endsWith(digitsB) || digitsB.endsWith(digitsA)) {
        return true;
      }
    }

    // 3. Coincidencia por nombre de contacto exacto
    final nameA = normalizeName(a.displayName);
    final nameB = normalizeName(b.displayName);
    if (nameA.isNotEmpty && nameA == nameB) {
      return true;
    }

    return false;
  }

  /// Fusiona dos items de la misma conversación priorizando los datos más recientes
  static ConversationSummaryItem mergeItems(
    ConversationSummaryItem existing,
    ConversationSummaryItem incoming,
  ) {
    final useIncoming = incoming.lastAtMs >= existing.lastAtMs;
    final latestMessage = useIncoming
        ? (incoming.lastMessage.isNotEmpty ? incoming.lastMessage : existing.lastMessage)
        : (existing.lastMessage.isNotEmpty ? existing.lastMessage : incoming.lastMessage);

    return ConversationSummaryItem(
      conversationId: existing.conversationId.startsWith('live:')
          ? incoming.conversationId
          : existing.conversationId,
      displayName: existing.displayName.length >= incoming.displayName.length
          ? existing.displayName
          : incoming.displayName,
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
      entryCount: math.max(existing.entryCount, incoming.entryCount) + 1,
      notificationKey: incoming.notificationKey ?? existing.notificationKey,
    );
  }

  /// Procesa una lista heterogénea y produce un listado deduplicado, ordenado y libre de ruido
  static List<ConversationSummaryItem> deduplicateAndSort(List<ConversationSummaryItem> input) {
    final valid = input.where((item) => isSupportedMessagingApp(item.packageName)).toList();
    final result = <ConversationSummaryItem>[];

    for (final item in valid) {
      var foundIndex = -1;
      for (var i = 0; i < result.length; i++) {
        if (areSameConversation(result[i], item)) {
          foundIndex = i;
          break;
        }
      }

      if (foundIndex >= 0) {
        result[foundIndex] = mergeItems(result[foundIndex], item);
      } else {
        result.add(item);
      }
    }

    result.sort((a, b) => b.lastAtMs.compareTo(a.lastAtMs));
    return result;
  }
}
