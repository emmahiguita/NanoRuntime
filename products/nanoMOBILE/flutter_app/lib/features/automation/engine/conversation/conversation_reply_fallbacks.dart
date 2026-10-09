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
    ConversationDialogueState? dialogueState,
  }) async {
    // El canal Business y el modo diagnóstico puro siguen la ruta de modelo.
    // El agente personal normal sí debe conservar la respuesta determinista:
    // evita latencia innecesaria y garantiza un fallback cuando el runtime local
    // todavía no está listo.
    if (isBusiness ||
        PersonalConversationDiagnostic.appliesTo(conversationId)) {
      return null;
    }

    final resolved = await _personalResolver.resolveEarlyTurn(
      notification: notification,
      analysis: analysis,
      memory: memory,
      conversationId: conversationId,
      dialogueState: dialogueState,
    );
    if (resolved == null) return null;

    return _packReply(
      resolved.text,
      resolved.understanding,
      resolved.suggestions,
      context,
      conversationId,
      resolved.isFast,
      userText: analysis.targetText,
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
            userText: analysis.targetText,
          );
        }
      }
      return null;
    }

    // El diagnóstico puro mide únicamente la salida real del modelo. Fuera de
    // ese modo, el agente personal conserva memoria, estilo y conocimiento como
    // recuperación honesta cuando el modelo no entrega un borrador.
    if (PersonalConversationDiagnostic.appliesTo(conversationId)) {
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
        userText: analysis.targetText,
      );
    }

    return null;
  }

  /// Aplica sanitización, validación semántica de salida y política de autonomía en un único punto.
  ConversationDraftResult _packReply(
    String reply,
    ConversationUnderstanding understanding,
    List<String> suggestions,
    ConversationDecisionContext context,
    String conversationId,
    bool isFast, {
    String userText = '',
  }) {
    ExecutionBudget.current?.check();
    final act = const DialogueActClassifier().classify(userText).primaryAct;
    final validation = _outputGate.validate(
      userText: userText,
      act: act,
      candidateReply: reply,
    );
    final personal = context.agentId == ConversationAgentId.personal;
    // Un match de persona ya pasó por ejemplos habilitados y verificados por el
    // dueño. Esa voz aprendida es la excepción deliberada a la política neutral;
    // las salidas generativas continúan rechazando jerga no autorizada.
    final trustedPersonaStyle = understanding.intent == 'persona_style_match';
    final languageAccepted =
        !personal ||
        trustedPersonaStyle ||
        PersonalLanguagePolicy.accepts(reply);
    // Rechazar es obligatorio: una salida no aprobada no se despacha ni se sustituye.
    if (personal && (!validation.isApproved || !languageAccepted)) {
      return packConversationDraftResult(
        reply: '',
        understanding: understanding.withRequiredAction(),
        suggestions: const [],
        context: context,
        conversationId: conversationId,
        isFastPath: isFast,
        decisionEngine: _decisionEngine,
        allowRepair: false,
      );
    }
    final safeReply = validation.isApproved
        ? reply
        : (validation.safeFallbackReply ?? reply);
    _dialogueStateTracker.recordUserTurn(
      conversationId,
      act,
      userText: userText,
    );
    // Un borrador no se registra como enviado: el siguiente turno usa evidencia de memoria.

    return packConversationDraftResult(
      reply: safeReply,
      // Conservar la salida real, pero retenerla si la barrera semántica falla.
      understanding: understanding,
      // Las variantes atraviesan la misma barrera que la respuesta principal.
      suggestions: suggestions
          .where(
            (candidate) =>
                (!personal ||
                    trustedPersonaStyle ||
                    PersonalLanguagePolicy.accepts(candidate)) &&
                _outputGate
                    .validate(
                      userText: userText,
                      act: act,
                      candidateReply: candidate,
                    )
                    .isApproved,
          )
          .toList(),
      context: context,
      conversationId: conversationId,
      isFastPath: isFast,
      decisionEngine: _decisionEngine,
      allowRepair: !personal,
    );
  }
}
