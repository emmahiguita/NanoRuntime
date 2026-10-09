part of 'conversation_reply_composer.dart';

// QUÉ: sincroniza continuidad con salidas observadas, nunca con borradores.
// CÓMO: recupera el último envío verificado o mensaje manual del historial real.
// POR QUÉ: sugerir, fallar o pedir revisión no significa haber hablado al contacto.
extension _ConversationDialogueEvidence on RuntimeConversationReplyComposer {
  void _syncDialogueEvidence(String id, ConversationMemory? memory) {
    ConversationMemoryEntry? confirmed;
    for (final entry
        in memory?.entries.reversed ?? const <ConversationMemoryEntry>[]) {
      if (entry.kind == ConversationMemoryEntryKind.outboundVerified ||
          entry.kind == ConversationMemoryEntryKind.outboundObservedManual) {
        confirmed = entry;
        break;
      }
    }
    if (confirmed == null || confirmed.text.trim().isEmpty) {
      return;
    }
    if (_dialogueStateTracker.getState(id).lastAgentStatement ==
        confirmed.text) {
      return;
    }
    _dialogueStateTracker.recordAgentTurn(
      conversationId: id,
      act: const DialogueActClassifier().classify(confirmed.text).primaryAct,
      statement: confirmed.text,
      isQuestion: confirmed.text.contains('?'),
    );
  }
}
