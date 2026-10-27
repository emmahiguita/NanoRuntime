/// Recupera mensajes únicamente de identidades comprobadas del mismo canal/cuenta.
/// No busca por nombre humano ni convierte resúmenes o borradores en historial.
library;

import '../../engine/messaging/conversation_memory.dart';
import '../../engine/messaging/conversation_hub_providers.dart';
import '../../engine/messaging/conversation_key.dart';
import '../messaging_center/messaging_conversation_identity.dart';
import 'observed_message_index.dart';

class ConversationHistoryResolver {
  const ConversationHistoryResolver();

  /// Una única política para memoria y selección de la notificación contestable.
  static bool belongsTo(
    ConversationSummaryItem selected,
    ConversationSummaryItem observed,
  ) => MessagingConversationIdentity.areSame(selected, observed);

  static List<ConversationMemoryEntry> resolve({
    required ConversationSummaryItem item,
    required ConversationMemoryStore store,
    List<ConversationMemoryEntry> liveEntries = const [],
  }) {
    final allEntries = <ConversationMemoryEntry>[];
    final observed = ObservedMessageIndex();
    void addEntries(List<ConversationMemoryEntry>? entries) {
      if (entries == null) return;
      for (final entry in entries) {
        if (observed.add(entry)) {
          allEntries.add(entry);
        }
      }
    }

    addEntries(liveEntries);
    final primary = canonicalConversationId(item.conversationId);
    final ids = <String>{
      item.conversationId,
      ...item.conversationAliases,
      ...store.knownConversationIds(),
    };
    for (final raw in ids) {
      final id = canonicalConversationId(raw);
      if (id.isEmpty) continue;
      if (id == primary) {
        addEntries(store.memoryFor(id)?.entries);
        continue;
      }
      // La evidencia de cuenta/paquete proviene del ID almacenado, no del
      // chat seleccionado. No se inventa scope para IDs heredados sin datos.
      final parts = id.split('/');
      if (parts.length < 4) continue;
      final observed = ConversationSummaryItem(
        conversationId: id,
        packageName: parts[1],
        displayName: '',
        lastMessage: '',
        lastAtMs: 0,
        agentId: item.agentId,
        isGroup: id.contains('@g.us'),
      );
      if (belongsTo(item, observed)) {
        addEntries(store.memoryFor(id)?.entries);
      }
    }
    allEntries.sort((a, b) => a.atMs.compareTo(b.atMs));
    return allEntries;
  }
}
