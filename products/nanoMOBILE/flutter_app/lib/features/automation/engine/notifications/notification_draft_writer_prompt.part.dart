part of 'notification_draft_writer.dart';

// QUÉ HACE: Compone el prompt que corresponde al rol y al tipo de turno.
// CÓMO FUNCIONA: Aplica el gate social, incorpora contexto válido y fija la sesión del input.
// POR QUÉ: Evita mezclar información comercial con respuestas personales.
final class _PreparedDraftPrompt {
  const _PreparedDraftPrompt({
    required this.messageText,
    required this.prompt,
    required this.sessionId,
    required this.isSocial,
    required this.persona,
    required this.systemContext,
    required this.maxTokens,
    required this.history,
    required this.stopwatch,
  });

  final String messageText;
  final String prompt;
  final String sessionId;
  final bool isSocial;
  final String persona;
  final String systemContext;
  final int maxTokens;
  final List<Map<String, String>>? history;
  final Stopwatch stopwatch;
}

_PreparedDraftPrompt _prepareDraftPrompt(
  RuntimeNotificationDraftWriter writer,
  NotificationObject notification,
  String conversationId,
  _ResolvedDraftContext context, {
  required bool includePersonaInPrompt,
}) {
  final msgText = context.messageText;
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
  // P0-ROUTE — hechos del negocio SOLO en turnos de venta. El selector
  // léxico (WA-BUSINESS-02) elige el subconjunto; el ROL decide si
  // entra. NO COMMERCIAL INTENT = NO SALES CONTEXT.
  // P0-MULTI — turno mixto ("¿está Emmanuel y todavía tienen el
  // Negro?"): rol personal por identidad PERO commercialIntent true →
  // <DATOS DEL NEGOCIO> entra igual: UNA respuesta con estilo del dueño
  // y facts reales (jamás un chat entre agentes).
  final isCommercial = agentId == ConversationAgentId.business;
  final business = isCommercial
      ? writer._businessBlock?.call(msgText) ?? ''
      : '';
  // FASE 8: El tono comercial (ToneProfile) entra ÚNICAMENTE en turnos
  // de venta. En turnos personales NUNCA entra el tono de ventas.
  final tone = isCommercial ? writer._toneBlock?.call() : null;
  final turnSession =
      '$conversationId|${RuntimeNotificationDraftWriter._flightFingerprint(notification)}';
  // Diagnóstico seguro previo al modelo: conserva longitudes y flags, nunca texto privado.
  debugPrint(
    '[ctx:prompt] conv=${_shortId(conversationId)} '
    'inputChars=${msgText.length} '
    'greeting=${isGreetingLikeMessage(msgText)} '
    'clientContext=${clientContext.isNotEmpty} '
    'historyEntries=${historyEntries.length} '
    'businessChars=${business.length} '
    'session=${_shortId(turnSession)}',
  );
  // P0-PERSONA-BASE — saludo puro: prompt SOCIAL mínimo (sin JSON ni
  // reglas largas) + maxTokens 128. Evidencia física: con el prompt
  // completo el 1.5B devuelve operador aunque la regla dura lo prohíba;
  // el guard lo retiene, pero el objetivo es respuesta cotidiana. El
  // social prompt no necesita estructura: el escalón legacy del parser
  // toma el texto tras "Respuesta:".
  // La ruta personal usa instrucciones compactas para bajar el prefill móvil;
  // ventas, producto mezclado y estado vivo conservan el prompt estructurado.
  final hasProductContext =
      routing?.reasons.contains(productMentionedWithoutCommerce) ?? false;
  final personalReply =
      agentId == ConversationAgentId.personal &&
      role == ConversationAgentRole.personal &&
      !hasProductContext &&
      !(routing?.pendingReply ?? false) &&
      !isLiveStateQuestion(msgText);
  // Personal local compacto; transferencias y estado vivo conservan JSON.
  final localConversation =
      agentId == ConversationAgentId.personal && !includePersonaInPrompt;
  final style =
      agentId == ConversationAgentId.personal && writer._styleEnabled()
      ? writer._styleText()
      : null;
  final identity = NanoIdentityContext.matches(msgText)
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
    if (identity.isNotEmpty) identity,
  ].join('\n');
  final genSw = Stopwatch()..start();
  final prompt = localConversation
      ? _personalTurnPrompt(msgText, persona, identity)
      : personalReply
      ? conversationSocialPromptFor(
          text: msgText,
          style: style,
          persona: includePersonaInPrompt ? persona : null,
          tone: tone,
          history: formatConversationHistory(socialEntries),
          temporalContext: temporalBlock,
          agentContract: agentContract,
        )
      : conversationAgentPromptFor(
          history: history,
          text: msgText,
          style: style,
          business: business,
          tone: tone,
          persona: includePersonaInPrompt ? persona : null,
          clientContext: clientContext,
          temporalContext: temporalBlock,
          agentContract: agentContract,
        );

  return _PreparedDraftPrompt(
    messageText: msgText,
    prompt: prompt,
    sessionId: turnSession,
    isSocial: personalReply,
    persona: persona,
    history: localConversation ? _personalTurnHistory(context) : null,
    systemContext: localConversation
        ? _personalSystemContext(
            contract: contract,
            identity: identity,
            style: style,
            structured: !personalReply,
          )
        : includePersonaInPrompt
        ? ''
        : persona,
    // Párrafos y preguntas compuestas necesitan más salida que un saludo.
    maxTokens:
        personalReply &&
            !turnComplexityClassifier.classify(msgText).isComplex &&
            msgText.length <= 240
        ? 128
        : 320,
    stopwatch: genSw,
  );
}
