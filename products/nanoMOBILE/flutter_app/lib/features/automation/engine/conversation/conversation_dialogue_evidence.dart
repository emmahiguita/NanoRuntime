part of 'conversation_reply_composer.dart';

// QUÉ: sincroniza continuidad con salidas observadas, nunca con borradores.
// CÓMO: recupera el último envío verificado o mensaje manual del historial real.
// POR QUÉ: sugerir, fallar o pedir revisión no significa haber hablado al contacto.
extension _ConversationDialogueEvidence on RuntimeConversationReplyComposer {
  void _syncDialogueEvidence(String id, ConversationMemory? memory) {
    ConversationMemoryEntry? confirmed;
    var answered = false;
    for (final entry
        in memory?.entries.reversed ?? const <ConversationMemoryEntry>[]) {
      // La ventana excluye el evento actual: una entrada posterior a la última
      // salida observada ya consumió esa pregunta/petición en un turno anterior.
      if (entry.kind == ConversationMemoryEntryKind.inbound) answered = true;
      if (entry.kind == ConversationMemoryEntryKind.outboundVerified ||
          entry.kind == ConversationMemoryEntryKind.outboundObservedManual) {
        confirmed = entry;
        break;
      }
    }
    if (confirmed == null || confirmed.text.trim().isEmpty) {
      return;
    }
    final pending =
        !answered &&
        (confirmed.text.contains('?') ||
            PersonalTurnContinuity.requestsLink(confirmed.text));
    final current = _dialogueStateTracker.getState(id);
    if (current.lastAgentStatement == confirmed.text &&
        current.hasPendingQuestion == pending) {
      return;
    }
    _dialogueStateTracker.recordAgentTurn(
      conversationId: id,
      act: const DialogueActClassifier().classify(confirmed.text).primaryAct,
      statement: confirmed.text,
      isQuestion: pending,
    );
  }
}
