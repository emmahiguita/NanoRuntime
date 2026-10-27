// Conecta frases editables, hechos y políticas al único flujo de mensajería.
// La identidad por evento impide que una notificación reutilizada bloquee todo el chat.
part of 'conversation_reply_composer.dart';

extension _ConversationBusinessReply on RuntimeConversationReplyComposer {
  Future<({bool handled, ConversationDraftResult? draft})>
  _resolveBusinessTurn({
    required NotificationObject notification,
    required String conversationId,
    required String fullText,
    required String eventId,
    required BusinessFacts facts,
    required ConversationDecisionContext context,
  }) async {
    final factual = (_businessResolver ?? const BusinessConversationResolver())
        .resolve(
          message: fullText,
          facts: facts,
          tone: _toneSource?.call() ?? const ToneProfile(),
        );
    final runtime = _businessRuntime ?? NanoBusinessRuntime(facts: facts);
    final result = await runtime.processTurn(
      eventId: eventId,
      conversationId: conversationId,
      incomingText: fullText,
      factualReply: factual,
      channel: notification.packageName.contains('w4b')
          ? 'whatsapp_business'
          : 'whatsapp',
    );
    // Un duplicado es un turno atendido, no una invitación a generar otro envío.
    if (result?.isDuplicate == true) return (handled: true, draft: null);
    if (result == null || result.replyText.isEmpty) {
      return (handled: false, draft: null);
    }
    final understanding = ConversationUnderstanding(
      reply: result.replyText,
      intent: 'business_commercial',
      requiresAction:
          result.isEscalatedToHuman ||
          result.requiresConfirmation ||
          !facts.profile.autoReply,
      options: result.suggestions,
    );
    return (
      handled: true,
      draft: _packReply(
        result.replyText,
        understanding,
        result.suggestions,
        context,
        conversationId,
        false,
        userText: notification.text,
      ),
    );
  }
}
