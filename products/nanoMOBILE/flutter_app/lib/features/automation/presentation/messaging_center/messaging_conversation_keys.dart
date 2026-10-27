/// Identidad compartida por filtros y acciones del centro de mensajería.
///
/// Solo utiliza IDs técnicos observados y aliases cuya equivalencia ya fue
/// probada por el deduplicador; nunca une chats por nombre o texto visible.
library;

import '../../engine/messaging/conversation_hub_providers.dart';
import '../../engine/messaging/conversation_key.dart';

Set<String> messagingConversationKeys(ConversationSummaryItem item) => {
  item.conversationId,
  ...item.conversationAliases,
}.map(canonicalConversationId).where((id) => id.isNotEmpty).toSet();

bool isMessagingConversationArchived(
  ConversationSummaryItem item,
  Set<String> archivedIds,
) => messagingConversationKeys(item).any(archivedIds.contains);

/// QUÉ: Determina si una conversación fue quitada del centro de Nano.
/// CÓMO: Comprueba si alguna de sus claves técnicas tiene un `removedAtMs`
/// mayor o igual al `lastAtMs` del resumen actual.
/// POR QUÉ: Oculta chats quitados (incluso de SQLite o WhatsApp Web), pero
/// permite que reaparezcan automáticamente si reciben un mensaje nuevo.
bool isMessagingConversationRemoved(
  ConversationSummaryItem item,
  Map<String, int> removedAtByKey,
) {
  if (removedAtByKey.isEmpty) return false;
  for (final key in messagingConversationKeys(item)) {
    final removedAt = removedAtByKey[key];
    if (removedAt != null && item.lastAtMs <= removedAt) {
      return true;
    }
  }
  return false;
}
