/// Ventana social factual para el prompt mínimo del Agente Personal.
///
/// QUÉ HACE: conserva solamente mensajes que Nano observó o verificó.
/// CÓMO: elimina efectos desconocidos y envíos no confirmados antes de aplicar
/// la recuperación temática; así un borrador fallido no se vuelve memoria.
/// POR QUÉ: evita eco, contaminación comercial y respuestas basadas en hechos
/// que nunca llegaron al chat real.
library;

import '../messaging/conversation_memory.dart';
import '../messaging/social_context_retriever.dart';

List<ConversationMemoryEntry> socialConversationWindow(
  List<ConversationMemoryEntry> entries, {
  int maxEntries = 4,
  String currentText = '',
  String currentSender = '',
  String? activeTopic,
}) {
  if (entries.isEmpty || maxEntries <= 0) return const [];
  final factual = entries.where(_isFactualSocialEntry).toList(growable: false);
  if (factual.isEmpty) return const [];
  return SocialContextRetriever.selectWindow(
    factual,
    currentText: currentText,
    currentSender: currentSender,
    activeTopic: activeTopic,
    maxEntries: maxEntries,
  );
}

bool _isFactualSocialEntry(ConversationMemoryEntry entry) {
  return switch (entry.kind) {
    ConversationMemoryEntryKind.inbound ||
    ConversationMemoryEntryKind.outboundObservedManual ||
    ConversationMemoryEntryKind.outboundVerified => true,
    ConversationMemoryEntryKind.outboundDispatched ||
    ConversationMemoryEntryKind.effectUnknown => false,
  };
}
