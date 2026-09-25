// conversation_reply_fallbacks.dart
//
// QUÉ HACE: concentra rutas rápidas personales y fallbacks factuales.
// CÓMO: cada candidato conserva la misma identidad, memoria y decisión final.
// POR QUÉ: evita duplicar prompts y mantiene cada unidad por debajo de 200 líneas.

part of 'conversation_reply_composer.dart';

extension _ConversationReplyFallbacks on RuntimeConversationReplyComposer {
  /// Delega la resolución temprana exclusivamente al resolver del agente personal.
  Future<ConversationDraftResult?> _personalEarlyReply({
    required NotificationObject notification,
    required TurnRoutingAnalysis analysis,
    required ConversationMemory? memory,
    required ConversationDecisionContext context,
    required String conversationId,
    required bool isBusiness,
  }) async {
    if (isBusiness) return null;

    final resolved = await _personalResolver.resolveEarlyTurn(
      notification: notification,
      analysis: analysis,
      memory: memory,
      conversationId: conversationId,
    );
    if (resolved == null) return null;

    return _packReply(
      resolved.text,
      resolved.understanding,
      resolved.suggestions,
      context,
      conversationId,
      resolved.isFast,
    );
  }

  /// Delega el fallback al agente correspondiente (Personal o Business) según el canal/rol.
  Future<ConversationDraftResult?> _fallbackReply({
    required TurnRoutingAnalysis analysis,
    required ConversationMemory? memory,
    required ConversationDecisionContext context,
    required String conversationId,
    required bool isBusiness,
    required BusinessFacts? businessFacts,
  }) async {
    // 1. Canal Comercial: delega en BusinessConversationResolver
    if (isBusiness && _businessResolver != null) {
      final facts = businessFacts ?? const BusinessFacts();
      final commercialAnalysis = _businessResolver.analyzer.analyze(
        analysis.fullText,
        facts,
      );
      if (commercialAnalysis.hasCommercialIntent || isBusiness) {
        final fallback = _businessResolver.resolve(
          message: analysis.fullText,
          facts: facts,
          tone: _toneSource?.call() ?? const ToneProfile(),
          businessName: facts.businessName,
        );
        if (fallback != null && fallback.text.isNotEmpty) {
          final understanding = ConversationUnderstanding(
            reply: fallback.text,
            intent: 'business_fallback',
            // Conserva la falta factual detectada: el fallback no puede
            // convertir una respuesta incompleta en una respuesta segura.
            requiresAction: fallback.needsHuman,
            missingFacts: fallback.missingFacts,
            options: fallback.suggestions,
          );
          return _packReply(
            fallback.text,
            understanding,
            fallback.suggestions,
            context,
            conversationId,
            true,
          );
        }
      }
      return null;
    }

    // 2. Canal Personal: delega en PersonalConversationResolver
    final personalFallback = await _personalResolver.resolveFallbackTurn(
      analysis: analysis,
      memory: memory,
      conversationId: conversationId,
    );
    if (personalFallback != null) {
      return _packReply(
        personalFallback.text,
        personalFallback.understanding,
        personalFallback.suggestions,
        context,
        conversationId,
        personalFallback.isFast,
      );
    }

    return null;
  }

  /// Aplica sanitización y política de autonomía en un único punto.
  ConversationDraftResult _packReply(
    String reply,
    ConversationUnderstanding understanding,
    List<String> suggestions,
    ConversationDecisionContext context,
    String conversationId,
    bool isFast,
  ) => packConversationDraftResult(
    reply: reply,
    understanding: understanding,
    suggestions: suggestions,
    context: context,
    conversationId: conversationId,
    isFastPath: isFast,
    decisionEngine: _decisionEngine,
  );
}
