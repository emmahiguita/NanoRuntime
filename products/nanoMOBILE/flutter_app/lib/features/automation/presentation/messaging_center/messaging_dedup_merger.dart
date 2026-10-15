/// MESSAGING-DEDUP-MERGER — Algoritmo canónico de deduplicación y fusión.
///
/// **QUÉ HACE:**
/// Fusiona el historial persistente de SQLite con las notificaciones vivas de Android
/// en una lista única de conversaciones reales, erradicando chats duplicados y alucinaciones.
///
/// **CÓMO FUNCIONA:**
/// Compara dos conversaciones por paquete + identidad técnica comprobable.
/// Si coinciden, actualiza el mensaje y hora más reciente.
/// Filtra estrictamente notificaciones del sistema (systemui, phonemanager, android).
///
/// **POR QUÉ:**
/// Cumple con Single Responsibility (SOLID) y la regla de archivos < 200 líneas.
library;

import '../../engine/messaging/conversation_hub_providers.dart';
import '../../engine/web_bridge/whatsapp_web_message_filter.dart';
import 'messaging_conversation_identity.dart';
import 'messaging_summary_merger.dart';
import 'social_messaging_panel_filter.dart';

abstract final class MessagingDedupMerger {
  /// Paquetes de mensajería reales permitidos (filtra apps del sistema como systemui o phonemanager)
  static const supportedPackages = {
    'com.whatsapp', 'com.whatsapp.w4b', 'org.telegram.messenger',
    'com.telegram.messenger', 'org.telegram.plus', 'com.instagram.android',
    'com.facebook.orca', 'com.facebook.mlite', 'com.facebook.katana',
    'com.facebook.lite', 'com.slack', 'com.google.android.gm',
    'com.twitter.android', 'com.linkedin.android',
  };

  /// Paquetes del sistema explícitamente vetados para evitar alucinaciones
  static const rejectedSystemPackages = {
    'android', 'com.android.systemui', 'com.coloros.phonemanager',
    'com.google.android.googlequicksearchbox', 'com.oppo.launcher',
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

  static String? extractPhoneDigits(String raw) =>
      MessagingConversationIdentity.extractPhoneDigits(raw);
  static bool areSameConversation(
    ConversationSummaryItem a,
    ConversationSummaryItem b,
  ) => MessagingConversationIdentity.areSame(a, b);

  static bool _isSpurious(ConversationSummaryItem item) {
    if (SocialMessagingPanelFilter.appliesTo(item.packageName)) {
      return !SocialMessagingPanelFilter.allows(item);
    }
    if (item.conversationId.toLowerCase().startsWith('waweb:')) {
      return !WhatsAppWebMessageFilter.allows(
        conversationId: item.conversationId,
        displayName: item.displayName,
        lastMessage: item.lastMessage,
      );
    }
    final name = item.displayName.trim().toLowerCase();
    final convId = item.conversationId.trim().toLowerCase();
    final lastMsg = item.lastMessage.trim().toLowerCase();

    if (convId.endsWith('/notification:0') ||
        (!item.messageVerified &&
            name.startsWith('whatsapp/') &&
            lastMsg.startsWith('iniciaste sesión en whatsapp'))) {
      return true;
    }

    if (name == '0' || convId == '0' || convId == 'live:0') return true;
    if (convId.contains('status@broadcast') || convId.contains('@newsletter')) return true;
    if (name == 'actualizaciones de estado' || name == 'status updates' ||
        name == 'actualizaciones' || name == 'novedades') {
      return true;
    }
    if (name.contains('comprobando si hay') || name.contains('buscando mensajes nuevos')) {
      return true;
    }
    if (lastMsg.contains('le gustó tu estado') || lastMsg.contains('le gusta tu estado') ||
        lastMsg.contains('dio me gusta a tu estado') || lastMsg.contains('reacted to your status') ||
        lastMsg.contains('replied to your status') || lastMsg.contains('comprobando si hay') ||
        lastMsg.contains('buscando mensajes nuevos')) {
      return true;
    }
    return false;
  }

  /// Agrupa equivalencias en O(n²) y fusiona cada componente una sola vez.
  static List<ConversationSummaryItem> deduplicateAndSort(
    List<ConversationSummaryItem> input,
  ) {
    final valid = input
        .where((item) => isSupportedMessagingApp(item.packageName) && !_isSpurious(item))
        .toList();

    final parents = List<int>.generate(valid.length, (index) => index);
    final representatives = List<ConversationSummaryItem>.of(valid);

    int rootOf(int index) {
      var current = index;
      while (parents[current] != current) {
        parents[current] = parents[parents[current]];
        current = parents[current];
      }
      return current;
    }

    bool uniqueWebTitlePair(int first, int second) {
      final a = valid[first], b = valid[second];
      final aWeb = a.conversationId.toLowerCase().startsWith('waweb:');
      final bWeb = b.conversationId.toLowerCase().startsWith('waweb:');
      if (aWeb == bWeb || a.packageName != b.packageName || a.isGroup != b.isGroup) {
        return false;
      }
      final title = MessagingConversationIdentity.normalizeTitle(a.displayName);
      if (title.isEmpty || title != MessagingConversationIdentity.normalizeTitle(b.displayName)) {
        return false;
      }
      final matches = valid.where((item) {
        return item.packageName == a.packageName &&
            item.isGroup == a.isGroup &&
            MessagingConversationIdentity.normalizeTitle(item.displayName) == title;
      }).length;
      return matches == 2;
    }

    void union(int first, int second, {bool allowUniqueWebTitle = false}) {
      final firstRoot = rootOf(first);
      final secondRoot = rootOf(second);
      if (firstRoot != secondRoot) {
        if (!allowUniqueWebTitle &&
            !areSameConversation(representatives[firstRoot], representatives[secondRoot])) {
          return;
        }
        representatives[firstRoot] = MessagingSummaryMerger.merge(
          representatives[firstRoot],
          representatives[secondRoot],
        );
        parents[secondRoot] = firstRoot;
      }
    }

    for (var first = 0; first < valid.length; first++) {
      for (var second = first + 1; second < valid.length; second++) {
        final strong = areSameConversation(valid[first], valid[second]);
        final uniqueWebTitle = !strong && uniqueWebTitlePair(first, second);
        if (strong || uniqueWebTitle) {
          union(first, second, allowUniqueWebTitle: uniqueWebTitle);
        }
      }
    }

    final grouped = <int, ConversationSummaryItem>{};
    for (var index = 0; index < valid.length; index++) {
      final root = rootOf(index);
      final existing = grouped[root];
      grouped[root] = existing == null
          ? valid[index]
          : MessagingSummaryMerger.merge(existing, valid[index]);
    }

    final result = grouped.values.toList(growable: false);
    result.sort((a, b) => b.lastAtMs.compareTo(a.lastAtMs));
    return result;
  }
}
