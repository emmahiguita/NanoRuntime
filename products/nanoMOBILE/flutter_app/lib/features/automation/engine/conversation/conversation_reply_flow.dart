// conversation_reply_flow.dart
//
// QUÉ HACE: ordena comprensión, redacción contextual y fallback del turno.
// CÓMO: resuelve una identidad/memoria y delega cada etapa especializada.
// POR QUÉ: mantiene el compositor pequeño y evita rutas paralelas de respuesta.

part of 'conversation_reply_composer.dart';

extension _ConversationReplyFlow on RuntimeConversationReplyComposer {
  Future<ConversationDraftResult?> _composeUniqueNotification(
    NotificationObject notification, {
    required String conversationId,
    required IncomingMessage incomingEvent,
    required ConversationDecisionContext context,
  }) async {
    final memory = await ConversationDurableContext.resolve(
      store: _memoryStore,
      conversationId: conversationId,
      notification: notification,
    );
    final isBusiness =
        notification.packageName == MessagingPackage.whatsappBusiness ||
        context.agentId == ConversationAgentId.business ||
        context.agentRole == ConversationAgentRole.sales;
    _syncDialogueEvidence(conversationId, memory);
    final dialogueState = _dialogueStateTracker.getState(conversationId);
    // Un adjunto/voz espera a percepción; un cierre textual ya puede detenerse.
    if (!isBusiness &&
        _canEvaluateBeforeMedia(notification) &&
        _personalPolicyBlocks(notification, dialogueState)) {
      return null;
    }
    final enrichment = await ConversationMediaEnricher.enrich(
      notification,
      allowCloudMedia: context.allowCloudMedia,
    );
    ExecutionBudget.current?.check();
    final effectiveNotification = enrichment.notification;
    final analysis = _turnRouter.analyze(
      // Clasificar la voz del contacto, no instrucciones halladas en un PDF.
      notification: notification.withText(
        enrichment.transcribedText ??
            ConversationMediaEnricher.caption(notification),
      ),
      memory: memory,
      isBusinessChannel: isBusiness,
      dialogueState: dialogueState,
    );

    // La política analiza la petición hablada o el pie original, nunca el OCR.
    if (!isBusiness &&
        _personalPolicyBlocks(
          notification.withText(
            enrichment.transcribedText ??
                ConversationMediaEnricher.caption(notification),
          ),
          dialogueState,
        )) {
      return null;
    }

    // 1. Canal Comercial: NanoBusinessRuntime con Inbox Durable, Estado, Verdad y Políticas
    BusinessFacts? businessFacts;
    if (isBusiness && (_businessRuntime != null || _factsSource != null)) {
      businessFacts =
          _factsSource?.call() ??
          _businessRuntime?.facts ??
          const BusinessFacts();
      final bResult = await _resolveBusinessTurn(
        notification: effectiveNotification,
        conversationId: conversationId,
        fullText: analysis.fullText,
        eventId: incomingEvent.eventId,
        facts: businessFacts,
        context: context,
      );
      if (bResult.handled) return bResult.draft;
    }

    // 2. Canal Personal: hechos de memoria y estilo aprendido, sin frases prefabricadas.
    final early = await _personalEarlyReply(
      notification: effectiveNotification,
      analysis: analysis,
      memory: memory,
      context: context,
      conversationId: conversationId,
      isBusiness: isBusiness,
      dialogueState: dialogueState,
    );
    if (early != null) return early;

    // 3. Control térmico: CRITICAL+ bloquea el turno; SEVERE degrada y la
    // puerta nativa (InferenceThermalGuard) admite solo paquetes livianos.
    final thermal = await _thermalStatus?.call();
    if (thermal != null && thermal >= 4) {
      debugPrint('[conversation-compose] thermal $thermal: suprimido');
      return null;
    }

    // 4. Inferencia contextual LLM local (casos complejos / narrativos)
    final draft = await _draftSource(effectiveNotification);
    if (draft != null && draft.hasReply) {
      final businessReviewRequired =
          isBusiness &&
          (businessFacts ?? _factsSource?.call())?.profile.autoReply == false;
      final understanding = businessReviewRequired
          ? draft.understanding.withRequiredAction()
          : draft.understanding;
      return _packReply(
        draft.reply,
        understanding,
        understanding.options,
        _decisionContext?.call(notification) ?? context,
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
