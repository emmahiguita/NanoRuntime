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
    ExecutionBudget.current?.check();
    final enrichment = await ConversationMediaEnricher.enrich(notification);
    ExecutionBudget.current?.check();
    final effectiveNotification = enrichment.notification;

    final conversationId = resolveConversationIdentity(
      effectiveNotification,
    ).key.id;
    final context =
        decisionContext ??
        _decisionContext?.call(effectiveNotification) ??
        const ConversationDecisionContext();
    final memory = await ConversationDurableContext.resolve(
      store: _memoryStore,
      conversationId: conversationId,
      notification: effectiveNotification,
    );
    final isBusiness =
        effectiveNotification.packageName ==
            MessagingPackage.whatsappBusiness ||
        context.agentId == ConversationAgentId.business ||
        context.agentRole == ConversationAgentRole.sales;
    _syncDialogueEvidence(conversationId, memory);
    final dialogueState = _dialogueStateTracker.getState(conversationId);
    final analysis = _turnRouter.analyze(
      notification: effectiveNotification,
      memory: memory,
      isBusinessChannel: isBusiness,
      dialogueState: dialogueState,
    );

    // 0. Deduplicación determinista: descarta ráfagas redundantes.
    final incomingEvent = IncomingMessage.fromNotification(effectiveNotification);
    final groupSender = effectiveNotification.isGroup
        ? (effectiveNotification.senderKey.isNotEmpty
            ? effectiveNotification.senderKey
            : effectiveNotification.sender)
        : null;
    if (_deduplicator.isDuplicate(
      conversationId,
      analysis.fullText,
      senderKey: groupSender,
      eventId: incomingEvent.eventId,
    )) {
      debugPrint('[conv:dedup] duplicate event=${incomingEvent.eventId.substring(0, 8)}');
      return null;
    }

    // 0.1 Guardas honestas ante medios no comprendidos: no responder a ciegas
    if (enrichment.audioUnprocessed || enrichment.photoUnprocessed) {
      final isAudio = enrichment.audioUnprocessed;
      final reply = isAudio
          ? '¿Me cuentas por texto lo que dice el audio?'
          : '¿Me cuentas qué quieres mostrarme en la foto?';
      final opts = [reply];
      return _packReply(
        reply,
        ConversationUnderstanding(
          reply: reply,
          intent: isAudio ? 'audio_unprocessed' : 'photo_unprocessed',
          options: opts,
        ),
        opts,
        context,
        conversationId,
        true,
        userText: effectiveNotification.text,
      );
    }

    // 0.2 Políticas Nano Personal: Silencio Inteligente ante Emojis/Stickers & Escalamiento
    if (!isBusiness) {
      final personalDecision = PersonalConversationAnalyzer.analyze(
        notification: effectiveNotification,
        dialogueState: dialogueState,
      );

      if (personalDecision.isSilent) {
        debugPrint('[personal-policy] SILENT: ${personalDecision.reason}');
        return null;
      }

      if (personalDecision.isRequireHuman) {
        debugPrint('[personal-policy] REQUIRE_HUMAN (${personalDecision.domain.name}): ${personalDecision.reason}');
        if (personalDecision.recruitmentEvent != null) {
          final ev = personalDecision.recruitmentEvent!;
          debugPrint('[recruitment] ${ev.platform} | ${ev.position} | ${ev.stage} | URL: ${ev.url}');
        }
        return null;
      }
    }

    // 1. Canal Comercial: NanoBusinessRuntime con Inbox Durable, Estado, Verdad y Políticas
    BusinessFacts? businessFacts;
    if (isBusiness && (_businessRuntime != null || _factsSource != null)) {
      businessFacts = _factsSource?.call() ?? const BusinessFacts();
      final bResult = await _resolveBusinessTurn(
        notification: effectiveNotification,
        conversationId: conversationId,
        fullText: analysis.fullText,
        facts: businessFacts,
        context: context,
      );
      if (bResult != null) return bResult;
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

    // 3. Control térmico: evita bloquear el dispositivo con inferencia pesada.
    final thermal = await _thermalStatus?.call();
    if (thermal != null && thermal >= 3) {
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

  Future<ConversationDraftResult?> _resolveBusinessTurn({
    required NotificationObject notification,
    required String conversationId,
    required String fullText,
    required BusinessFacts facts,
    required ConversationDecisionContext context,
  }) async {
    final runtime = _businessRuntime ?? NanoBusinessRuntime(facts: facts);
    final result = await runtime.processTurn(
      eventId: notification.key,
      conversationId: conversationId,
      incomingText: fullText,
      channel: notification.packageName.contains('w4b')
          ? 'whatsapp_business'
          : 'whatsapp',
    );
    if (result == null || result.replyText.isEmpty) return null;
    final understanding = ConversationUnderstanding(
      reply: result.replyText,
      intent: 'business_commercial',
      requiresAction: result.isEscalatedToHuman,
      options: result.suggestions,
    );
    return _packReply(
      result.replyText,
      understanding,
      result.suggestions,
      context,
      conversationId,
      false,
      userText: notification.text,
    );
  }
}
