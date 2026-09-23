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
import 'messaging_conversation_identity.dart';
import 'messaging_summary_merger.dart';

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
    if (cleanPkg.startsWith('com.android.') ||
        cleanPkg.startsWith('com.coloros.')) {
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

  /// Agrupa equivalencias en O(n²) y fusiona cada componente una sola vez.
  /// Evita el reinicio de recorrido anterior, que podía crecer hasta O(n³).
  static List<ConversationSummaryItem> deduplicateAndSort(
    List<ConversationSummaryItem> input,
  ) {
    final valid = input
        .where((item) => isSupportedMessagingApp(item.packageName))
        .toList();
    final parents = List<int>.generate(valid.length, (index) => index);

    int rootOf(int index) {
      var current = index;
      while (parents[current] != current) {
        parents[current] = parents[parents[current]];
        current = parents[current];
      }
      return current;
    }

    void union(int first, int second) {
      final firstRoot = rootOf(first);
      final secondRoot = rootOf(second);
      if (firstRoot != secondRoot) parents[secondRoot] = firstRoot;
    }

    for (var first = 0; first < valid.length; first++) {
      for (var second = first + 1; second < valid.length; second++) {
        if (areSameConversation(valid[first], valid[second])) {
          union(first, second);
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
