part of 'conversation_detail_sheet.dart';

/// Aprende únicamente de mensajes enviados y verificados por el dueño.
extension ConversationDetailStyleLearning on _ConversationDetailSheetState {
  Future<void> _recordStyleLearning(String text) async {
    if (_agentId != ConversationAgentId.personal) return;
    final conversationId = canonicalConversationId(widget.item.conversationId);
    final personaContext = ref.read(personaContextProvider);
    if (!personaContext.allowsStyleLearningFor(
      widget.item.displayName,
      conversationId: conversationId,
    )) {
      return;
    }
    final lastMsg = widget.item.lastMessage.trim();
    final isRealIncoming =
        lastMsg.isNotEmpty && !RegExp(r'^\+?[0-9\s\-]+$').hasMatch(lastMsg);
    if (!isRealIncoming) return;

    try {
      final originalDraft = widget.item.pendingReplyText?.trim();
      final cleanText = text.trim();
      if (originalDraft != null &&
          originalDraft.isNotEmpty &&
          originalDraft == cleanText) {
        return;
      }
      final isCorrection =
          originalDraft != null &&
          originalDraft.isNotEmpty &&
          originalDraft != cleanText;
      await PersonalReplyLearningService.instance.learnVerifiedReply(
        incomingText: lastMsg,
        replyText: cleanText,
        source: isCorrection ? 'correction' : 'messaging_center_learning',
        correctedFrom: isCorrection ? originalDraft : null,
      );
    } catch (_) {}
  }
}
