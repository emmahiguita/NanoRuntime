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

    // 0. Deduplicación determinista: descarta ráfagas redundantes de WhatsApp.
    // En chats grupales discrimina por remitente para evitar descartar mensajes válidos entre usuarios.
    final incomingEvent = IncomingMessage.fromNotification(
      effectiveNotification,
    );
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
      final eventTag = incomingEvent.eventId.substring(0, 8);
      debugPrint(
        '[conv:dedup] duplicate event=$eventTag '
        'textChars=${analysis.fullText.length}',
      );
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
}
