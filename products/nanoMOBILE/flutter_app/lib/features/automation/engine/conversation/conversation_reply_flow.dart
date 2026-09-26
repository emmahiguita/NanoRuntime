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
    final dialogueState = _dialogueStateTracker.getState(conversationId);
    final analysis = _turnRouter.analyze(
      notification: notification,
      memory: memory,
      isBusinessChannel: isBusiness,
      dialogueState: dialogueState,
    );

    // 0. Deduplicación determinista: descarta ráfagas redundantes de WhatsApp.
    // En chats grupales discrimina por remitente para evitar descartar mensajes válidos entre usuarios.
    final incomingEvent = IncomingMessage.fromNotification(notification);
    final groupSender = notification.isGroup
        ? (notification.senderKey.isNotEmpty
            ? notification.senderKey
            : notification.sender)
        : null;
    if (_deduplicator.isDuplicate(
      conversationId,
      analysis.fullText,
      senderKey: groupSender,
      eventId: incomingEvent.eventId,
    )) {
      final eventTag = incomingEvent.eventId.substring(0, 8);
      debugPrint(
        '[conv:dedup] duplicate event=$eventTag '
        'textChars=${analysis.fullText.length}',
      );
      return null;
    }

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
            userText: analysis.targetText,
          );
        }
      }
    }

    // 2. Canal Personal: hechos de memoria y estilo aprendido, sin frases prefabricadas.
    final early = await _personalEarlyReply(
      notification: notification,
      analysis: analysis,
      memory: memory,
      context: context,
      conversationId: conversationId,
      isBusiness: isBusiness,
      dialogueState: dialogueState,
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
        userText: analysis.targetText,
      );
    }

    // 5. Recuperación secundaria con evidencia; si no alcanza, el turno queda sin enviar.
    final fallback = await _fallbackReply(
      analysis: analysis,
      memory: memory,
      context: context,
      conversationId: conversationId,
      isBusiness: isBusiness,
      businessFacts: businessFacts,
    );
    if (fallback == null || !fallback.hasReply) {
      // Explica por qué terminó el turno sin filtrar el mensaje ni la identidad.
      debugPrint(
        '[conversation-compose] no reply agent=${isBusiness ? 'business' : 'personal'} '
        'draft=${draft == null ? 'unavailable' : 'empty'} fallback=no_candidate',
      );
    }
    return fallback;
  }
}
