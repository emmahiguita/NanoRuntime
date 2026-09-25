// conversation_reply_flow.dart
//
// QUÉ HACE: ordena comprensión, redacción contextual y fallback del turno.
// CÓMO: resuelve una identidad/memoria y delega cada etapa especializada.
// POR QUÉ: mantiene el compositor pequeño y evita rutas paralelas de respuesta.

part of 'conversation_reply_composer.dart';

extension _ConversationReplyFlow on RuntimeConversationReplyComposer {
  Future<ConversationDraftResult?> _composeConversation(
    NotificationObject notification, {
    ConversationDecisionContext? decisionContext,
  }) async {
    final conversationId = resolveConversationIdentity(notification).key.id;
    final context =
        decisionContext ??
        _decisionContext?.call(notification) ??
        const ConversationDecisionContext();
    final memory = ConversationContextResolver.resolve(
      store: _memoryStore,
      conversationId: conversationId,
      notification: notification,
    );
    final isBusiness =
        notification.packageName == MessagingPackage.whatsappBusiness ||
        context.agentId == ConversationAgentId.business ||
        context.agentRole == ConversationAgentRole.sales;
    final analysis = _turnRouter.analyze(
      notification: notification,
      memory: memory,
      isBusinessChannel: isBusiness,
    );

    // 1. Canal Comercial: BusinessConversationResolver atiende de forma directa e inmediata (<5ms, 0 tokens)
    // estrictamente cuando hay intención comercial real (producto, servicio, hechos del negocio).
    // Un saludo aislado ("Hola") no activa el resolutor de ventas para no forzar venta ni catálogo.
    BusinessFacts? businessFacts;
    if (isBusiness && _businessResolver != null) {
      businessFacts = _factsSource?.call() ?? const BusinessFacts();
      final commercialAnalysis = _businessResolver.analyzer.analyze(
        analysis.fullText,
        businessFacts,
      );
      if (commercialAnalysis.hasCommercialIntent ||
          commercialAnalysis.isGreeting ||
          commercialAnalysis.isHumanRequest) {
        final tone = _toneSource?.call() ?? const ToneProfile();
        final bReply = _businessResolver.resolve(
          message: analysis.fullText,
          facts: businessFacts,
          tone: tone,
          businessName: businessFacts.businessName,
        );
        if (bReply != null && bReply.text.isNotEmpty) {
          final understanding = ConversationUnderstanding(
            reply: bReply.text,
            intent: 'business_commercial',
            requiresAction: bReply.needsHuman,
            missingFacts: bReply.missingFacts,
            options: bReply.suggestions,
          );
          return _packReply(
            bReply.text,
            understanding,
            bReply.suggestions,
            context,
            conversationId,
            true,
          );
        }
      }
    }

    // 2. Canal Personal: atajos deterministas FTS4 y PragmaticFastPath
    final early = await _personalEarlyReply(
      notification: notification,
      analysis: analysis,
      memory: memory,
      context: context,
      conversationId: conversationId,
      isBusiness: isBusiness,
    );
    if (early != null) return early;

    // 3. Control térmico: evita bloquear el dispositivo con inferencia pesada.
    final thermal = await _thermalStatus?.call();
    if (thermal != null && thermal >= 4) {
      debugPrint('[conversation-compose] thermal $thermal: suprimido');
      return null;
    }

    // 4. Inferencia contextual LLM local (casos complejos / narrativos)
    final draft = await _draftSource(notification);
    if (draft != null && draft.hasReply) {
      return _packReply(
        draft.reply,
        draft.understanding,
        draft.understanding.options,
        context,
        conversationId,
        false,
      );
    }

    // 5. Fallback factual y cortés final
    return _fallbackReply(
      analysis: analysis,
      memory: memory,
      context: context,
      conversationId: conversationId,
      isBusiness: isBusiness,
      businessFacts: businessFacts,
    );
  }
}
