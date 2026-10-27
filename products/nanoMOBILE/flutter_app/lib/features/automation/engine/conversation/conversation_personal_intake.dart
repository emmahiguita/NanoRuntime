part of 'conversation_reply_composer.dart';

/// QUÉ: filtros de entrada antes de gastar recursos en percepción o inferencia.
/// CÓMO: deduplica por evento original y consulta la política personal común.
/// POR QUÉ: OCR/transcripción no deben procesarse dos veces ni decidir permisos.
extension _ConversationPersonalIntake on RuntimeConversationReplyComposer {
  /// Reserva el evento antes de esperar; libera esa reserva si el turno falla.
  /// Un error de OCR/SQL no debe convertir un reintento en «duplicado enviado».
  Future<ConversationDraftResult?> _composeConversation(
    NotificationObject notification, {
    ConversationDecisionContext? decisionContext,
  }) async {
    ExecutionBudget.current?.check();
    final context =
        decisionContext ??
        _decisionContext?.call(notification) ??
        const ConversationDecisionContext();
    if (!context.groupReplyAllowed) return null;
    final id = resolveConversationIdentity(notification).key.id;
    final event = IncomingMessage.fromNotification(notification);
    if (_ignoreDuplicate(notification, id, event)) return null;
    try {
      return await _composeUniqueNotification(
        notification,
        conversationId: id,
        incomingEvent: event,
        context: context,
      );
    } on Object {
      _deduplicator.forgetEvent(id, event.eventId);
      rethrow;
    }
  }

  bool _ignoreDuplicate(
    NotificationObject notification,
    String conversationId,
    IncomingMessage event,
  ) {
    final duplicate = _deduplicator.isDuplicate(
      conversationId,
      notification.sourceText,
      senderKey: notification.isGroup
          ? (notification.senderKey.isNotEmpty
                ? notification.senderKey
                : notification.sender)
          : null,
      eventId: event.eventId,
    );
    if (duplicate) debugPrint('[conv:dedup] duplicate event');
    return duplicate;
  }

  /// Solo decide anticipadamente sobre texto o URL aislada, nunca sobre voz
  /// todavía no transcrita ni sobre un archivo que el canal acaba de adjuntar.
  bool _canEvaluateBeforeMedia(NotificationObject notification) =>
      notification.attachments.isEmpty &&
      (PersonalTurnContinuity.isBareLink(notification.sourceText) ||
          !ParsedMediaMessage.parse(notification.sourceText).hasMedia);

  /// Un bloqueo conserva silencio; el texto privado no se copia al registro.
  bool _personalPolicyBlocks(
    NotificationObject notification,
    ConversationDialogueState state,
  ) {
    final decision = PersonalConversationAnalyzer.analyze(
      notification: notification,
      dialogueState: state,
    );
    final blocked = decision.isSilent || decision.isRequireHuman;
    if (blocked) {
      debugPrint(
        '[personal-policy] action=${decision.action.name} '
        'domain=${decision.domain.name}',
      );
    }
    return blocked;
  }
}
