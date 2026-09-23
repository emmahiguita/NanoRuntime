part of 'conversation_detail_sheet.dart';

/// Aprende únicamente de mensajes enviados y verificados por el dueño.
extension ConversationDetailStyleLearning on _ConversationDetailSheetState {
  Future<void> _recordStyleLearning(String text) async {
    final lastMsg = widget.item.lastMessage.trim();
    final isRealIncoming =
        lastMsg.isNotEmpty && !RegExp(r'^\+?[0-9\s\-]+$').hasMatch(lastMsg);
    if (!isRealIncoming) return;

    try {
      final originalDraft = widget.item.pendingReplyText?.trim();
      final isCorrection =
          originalDraft != null &&
          originalDraft.isNotEmpty &&
          originalDraft != text;
      // Una sola puerta de aprendizaje comparte las reglas de deduplicación
      // con las respuestas manuales observadas directamente en WhatsApp.
      await PersonalReplyLearningService.instance.learnVerifiedReply(
        incomingText: lastMsg,
        replyText: text,
        source: isCorrection ? 'correction' : 'messaging_center_learning',
        correctedFrom: isCorrection ? originalDraft : null,
      );
    } catch (_) {}
  }
}
