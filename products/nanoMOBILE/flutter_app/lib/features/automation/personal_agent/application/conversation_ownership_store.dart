/// PERSONA-HANDOFF-03 — store de ownership por conversación.
///
/// Contrato puro: PERSONA-STORAGE-04 lo reemplazará por la implementación
/// SQLite (sección `conversation_ownership`, DB v3). El contrato NO cambia,
/// solo el respaldo — el DecisionEngine y la UI dependen de esta interfaz.
library;

import '../domain/conversation_owner.dart';

abstract interface class ConversationOwnershipStore {
  /// Dueño actual de la conversación. null = nunca hubo control humano
  /// explícito → el bot es dueño por defecto.
  ConversationOwnership? ownershipFor(String conversationId);

  /// Declara el control: humano toma la conversación o la devuelve al bot.
  /// Devuelve el estado resultante.
  ConversationOwnership setOwner(
    String conversationId,
    ConversationOwner owner, {
    int? nowMs,
  });

  /// Devuelve el control al bot (atajo de [setOwner]).
  ConversationOwnership release(String conversationId);
}

/// Implementación en memoria (proceso). La usa PERSONA-HANDOFF-03 hasta que
/// PERSONA-STORAGE-04 persista la sección en SQLite — el contrato ya quedó
/// fijado para que el cambio sea de respaldo, no de forma.
final class InMemoryConversationOwnershipStore
    implements ConversationOwnershipStore {
  final Map<String, ConversationOwnership> _byConversation = {};

  @override
  ConversationOwnership? ownershipFor(String conversationId) =>
      _byConversation[conversationId];

  @override
  ConversationOwnership setOwner(
    String conversationId,
    ConversationOwner owner, {
    int? nowMs,
  }) {
    final ownership = ConversationOwnership(
      conversationId: conversationId,
      owner: owner,
      updatedAtMs: nowMs ?? DateTime.now().millisecondsSinceEpoch,
    );
    _byConversation[conversationId] = ownership;
    return ownership;
  }

  @override
  ConversationOwnership release(String conversationId) =>
      setOwner(conversationId, ConversationOwner.bot);
}
