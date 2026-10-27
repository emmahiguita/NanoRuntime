part of 'notification_draft_writer.dart';

/// Compone el [_PreparedDraftPrompt] según el rol del agente y la complejidad.
_PreparedDraftPrompt _prepareDraftPrompt(
  RuntimeNotificationDraftWriter writer,
  NotificationObject notification,
  String conversationId,
  _ResolvedDraftContext context, {
  required bool includePersonaInPrompt,
}) {
  final msgText = includePersonaInPrompt
      ? context.messageText
      : MediaPromptBudget.fit(
          context.messageText,
          modelPath: writer._modelPath() ?? '',
        );
  final history = context.history;
  final historyEntries = context.historyEntries;
  final socialEntries = context.socialEntries;
  final routing = context.routing;
  final agentId = context.agentId;
  final role = context.role;
  final persona = context.persona;
  final clientContext = agentId == ConversationAgentId.business
      ? writer._clientContextFor?.call(conversationId, msgText) ?? ''
      : '';
  final isCommercial = agentId == ConversationAgentId.business;
  final business = isCommercial
      ? writer._businessBlock?.call(msgText) ?? ''
      : '';
  final tone = isCommercial ? writer._toneBlock?.call() : null;
  final turnSession = '${agentId.name}|$conversationId';

  debugPrint(
    '[ctx:prompt] conv=${_shortId(conversationId)} '
    'inputChars=${msgText.length} '
    'greeting=${isGreetingLikeMessage(msgText)} '
    'historyEntries=${historyEntries.length} '
    'session=${_shortId(turnSession)}',
  );

  final hasProductContext =
      routing?.reasons.contains(productMentionedWithoutCommerce) ?? false;
  final personalReply =
      agentId == ConversationAgentId.personal &&
      role == ConversationAgentRole.personal &&
      !hasProductContext &&
      !(routing?.pendingReply ?? false) &&
      (!isLiveStateQuestion(notification.requestText) ||
          !includePersonaInPrompt);
  final localConversation =
      agentId == ConversationAgentId.personal && !includePersonaInPrompt;
  final style =
      agentId == ConversationAgentId.personal && writer._styleEnabled()
      ? writer._styleText()
      : null;
  final identity = NanoIdentityContext.matches(notification.requestText)
      ? NanoIdentityContext.promptBlock(
          modelPath: writer._modelPath(),
          provider: includePersonaInPrompt
              ? writer._cloudInferencePort?.providerId ?? 'cloud'
              : 'local en este dispositivo',
        )
      : '';
  final temporalBlock = localConversation
      ? ''
      : TemporalLocationContext.promptBlock();
  final contract = conversationAgentContract(
    agentId,
    compact: localConversation,
  );
  final agentContract = [
    contract,
    if (agentId == ConversationAgentId.personal && includePersonaInPrompt)
      PersonalPromptPolicy.base,
    if (identity.isNotEmpty) identity,
  ].join('\n');
  final genSw = Stopwatch()..start();
  final pure = localConversation && personalReply && identity.isEmpty;
  final compactSystem =
      localConversation &&
      identity.isEmpty &&
      _needsCompactPersonalSystem(writer._modelPath());
  final effectivePersona = _personaForCapacity(
    writer._modelPath() ?? '',
    identity.isEmpty ? persona : '',
    style: localConversation ? style : null,
  );
  final liveContext = [
    if (!pure && context.historyNotice.isNotEmpty) context.historyNotice,
    if (context.liveEvidence.block.isNotEmpty) context.liveEvidence.block,
  ].join('\n');

  final prompt = pure
      ? _personalTurnPrompt(
          msgText,
          effectivePersona,
          liveFacts: liveContext.trim(),
        )
      : localConversation
      ? _personalTurnPrompt(msgText, effectivePersona, liveFacts: liveContext)
      : personalReply
      ? conversationSocialPromptFor(
          text: msgText,
          style: style,
          persona: includePersonaInPrompt ? persona : null,
          tone: tone,
          history: formatConversationHistory(socialEntries),
          temporalContext: [
            temporalBlock,
            context.historyNotice,
            context.liveEvidence.block,
          ].join('\n'),
          agentContract: agentContract,
        )
      : conversationAgentPromptFor(
          history: history,
          text: msgText,
          personal: agentId == ConversationAgentId.personal,
          style: style,
          business: business,
          tone: tone,
          persona: includePersonaInPrompt ? persona : null,
          clientContext: clientContext,
          temporalContext: [
            temporalBlock,
            context.historyNotice,
            context.liveEvidence.block,
          ].join('\n'),
          agentContract: agentContract,
        );

  return _PreparedDraftPrompt(
    messageText: msgText,
    prompt: prompt,
    sessionId: turnSession,
    isSocial: personalReply,
    persona: persona,
    history: localConversation
        ? _personalTurnHistory(
            context,
            nativeWindow: pure || context.canonicalHistory,
            diagnosticWindow: PersonalConversationDiagnostic.appliesTo(
              conversationId,
            ),
          )
        : null,
    systemContext: pure
        ? _nativePersonalSystem()
        : compactSystem
        ? _capacityPersonalSystem(structured: !personalReply)
        : localConversation
        ? _personalSystemContext(
            contract: contract,
            identity: identity,
            structured: !personalReply,
          )
        : includePersonaInPrompt
        ? ''
        : persona,
    maxTokens:
        personalReply &&
            !turnComplexityClassifier.classify(msgText).isComplex &&
            msgText.length <= 240
        ? 128
        : 320,
    stopwatch: genSw,
  );
}
