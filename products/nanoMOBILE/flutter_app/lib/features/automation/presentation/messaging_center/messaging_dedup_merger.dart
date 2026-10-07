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

import 'package:flutter/foundation.dart' show debugPrint;

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

  static bool _isSpurious(ConversationSummaryItem item) {
    final name = item.displayName.trim().toLowerCase();
    final convId = item.conversationId.trim().toLowerCase();
    final lastMsg = item.lastMessage.trim().toLowerCase();

    if (name == '0' || convId == '0' || convId == 'live:0') return true;
    if (convId.contains('status@broadcast') || convId.contains('@newsletter')) {
      return true;
    }
    if (name == 'actualizaciones de estado' ||
        name == 'status updates' ||
        name == 'actualizaciones' ||
        name == 'novedades') {
      return true;
    }
    if (name.contains('comprobando si hay') ||
        name.contains('buscando mensajes nuevos')) {
      return true;
    }
    if (lastMsg.contains('le gustó tu estado') ||
        lastMsg.contains('le gusta tu estado') ||
        lastMsg.contains('dio me gusta a tu estado') ||
        lastMsg.contains('reacted to your status') ||
        lastMsg.contains('replied to your status') ||
        lastMsg.contains('comprobando si hay') ||
        lastMsg.contains('buscando mensajes nuevos')) {
      return true;
    }
    return false;
  }

  /// Agrupa equivalencias en O(n²) y fusiona cada componente una sola vez.
  /// Evita el reinicio de recorrido anterior, que podía crecer hasta O(n³).
  /// Loguea cada paso para auditoría en tiempo real vía logcat.
  static List<ConversationSummaryItem> deduplicateAndSort(
    List<ConversationSummaryItem> input,
  ) {
    debugPrint(
      '[msgcenter:dedup] input=${input.length} '
      'ids=${input.map((e) => '"${e.conversationId.substring(0, e.conversationId.length.clamp(0, 20))}"').join(',')}',
    );

    final valid = input
        .where(
          (item) =>
              isSupportedMessagingApp(item.packageName) && !_isSpurious(item),
        )
        .toList();

    debugPrint(
      '[msgcenter:dedup] valid=${valid.length} filtered=${input.length - valid.length}',
    );

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
      if (firstRoot != secondRoot) {
        debugPrint(
          '[msgcenter:dedup] merge '
          '"${valid[first].displayName}"(${valid[first].conversationId.substring(0, valid[first].conversationId.length.clamp(0, 24))}) '
          '+ "${valid[second].displayName}"(${valid[second].conversationId.substring(0, valid[second].conversationId.length.clamp(0, 24))})',
        );
        parents[secondRoot] = firstRoot;
      }
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

    debugPrint(
      '[msgcenter:dedup] result=${result.length} '
      'names=${result.map((e) => '"${e.displayName}"').join(',')}',
    );

    return result;
  }
}
