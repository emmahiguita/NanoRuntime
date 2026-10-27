/// Compara snapshots Web sin emitir eventos ni tocar almacenamiento.
library;

import 'whatsapp_web_conversation_decoder.dart';

final class WhatsAppWebConversationSnapshot {
  const WhatsAppWebConversationSnapshot._();

  /// QUÉ: determina si dos listas representan exactamente el mismo DOM útil.
  /// CÓMO: compara orden y campos visibles en una sola pasada O(n).
  /// POR QUÉ: MutationObserver puede repetir snapshots y causar rebuild/SQLite.
  static bool same(
    List<WhatsAppWebConversationSummary> current,
    List<WhatsAppWebConversationSummary> next,
  ) {
    if (identical(current, next)) return true;
    if (current.length != next.length) return false;
    for (var index = 0; index < current.length; index++) {
      final a = current[index];
      final b = next[index];
      if (a.id != b.id ||
          a.displayName != b.displayName ||
          a.lastMessage != b.lastMessage ||
          a.timeLabel != b.timeLabel ||
          a.lastAtMs != b.lastAtMs ||
          a.unreadCount != b.unreadCount ||
          a.isGroup != b.isGroup) {
        return false;
      }
    }
    return true;
  }
}
