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
