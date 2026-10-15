/// Recupera mensajes únicamente de identidades comprobadas del mismo canal/cuenta.
/// No busca por nombre humano ni convierte resúmenes o borradores en historial.
library;

import '../../engine/messaging/conversation_memory.dart';
import '../../engine/messaging/conversation_hub_providers.dart';
import '../../engine/messaging/conversation_key.dart';
import '../messaging_center/messaging_conversation_identity.dart';

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
    void addEntries(List<ConversationMemoryEntry>? entries) {
      if (entries == null) return;
      for (final entry in entries) {
        if (!allEntries.any((saved) => _sameObservedMessage(saved, entry))) {
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

  /// Android y SQLite pueden registrar el mismo evento con una diferencia
  /// mínima entre `messageTimestamp` y `postTime`; se compara esa tolerancia
  /// además del eventId para que una burbuja real aparezca una sola vez.
  static bool _sameObservedMessage(
    ConversationMemoryEntry a,
    ConversationMemoryEntry b,
  ) {
    if (a.eventId.isNotEmpty && b.eventId.isNotEmpty) {
      // El EventChannel y SQLite pueden asignar ids técnicos distintos al
      // mismo mensaje. Un id igual prueba duplicidad; uno distinto no impide
      // continuar con la evidencia de contenido y hora.
      if (a.eventId == b.eventId) return true;
    }
    final sameText = a.text.trim().toLowerCase() == b.text.trim().toLowerCase();
    final provisionalConfirmation =
        (a.kind == ConversationMemoryEntryKind.outboundDispatched &&
            b.kind == ConversationMemoryEntryKind.outboundVerified) ||
        (b.kind == ConversationMemoryEntryKind.outboundDispatched &&
            a.kind == ConversationMemoryEntryKind.outboundVerified);
    // Aceptación y confirmación son dos estados del mismo envío, no dos burbujas.
    if (provisionalConfirmation &&
        sameText &&
        (a.atMs - b.atMs).abs() <= 30000) {
      return true;
    }
    final sameDirection =
        (a.kind == ConversationMemoryEntryKind.inbound) ==
        (b.kind == ConversationMemoryEntryKind.inbound);
    final senderA = a.sender.trim().toLowerCase();
    final senderB = b.sender.trim().toLowerCase();
    final sameSender = senderA.isEmpty || senderB.isEmpty || senderA == senderB;
    return sameDirection &&
        sameSender &&
        (a.atMs - b.atMs).abs() <= 2000 &&
        sameText;
  }
}
