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
    required this.stopwatch,
  });

  final String messageText;
  final String prompt;
  final String sessionId;
  final bool isSocial;
  final String persona;
  final Stopwatch stopwatch;
}

_PreparedDraftPrompt _prepareDraftPrompt(
  RuntimeNotificationDraftWriter writer,
  NotificationObject notification,
  String conversationId,
  _ResolvedDraftContext context,
) {
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
  // WA-CONV-UNDERSTANDING-01 — clasificador centralizado: cierra la fuga
  // PragmaticFastPath → NULL → socialPrompt. Un turno narrativo/contextual
  // /complejo JAMÁS usa el prompt mínimo aunque pase por isGreetingLikeMessage
  // o isSocialReactionMessage (la fuga exacta del bug). El clasificador es
  // determinista, 0 LLM, compartido entre el FastPath y el DraftWriter.
  final complexity = turnComplexityClassifier.classify(msgText);

  // P0-SOCIAL-2 — reacción social pura ("me alegra", "gracias", "dale")
  // usa el MISMO prompt mínimo: el router ya la marcó personal
  // y el prompt completo la empujó a operador. Excepción:
  // turno mixto con producto mencionado conserva el prompt completo
  // para responder al producto.
  // R5-GREETING-01 — saludo extendido usa el social mínimo igual que el
  // puro: con 60 entradas de historial el prompt completo revienta ctx=256.
  // CONV-STATE-02 — la respuesta a la pregunta pendiente JAMÁS usa el
  // social mínimo aunque empiece con saludo ("hola si").
  // WA-CONV-UNDERSTANDING-01 — invariante: !eligibleForSocialPrompt suprime
  // el social mínimo cuando el turno es narrativo/contextual/complejo.
  final social =
      agentId == ConversationAgentId.personal &&
      role == ConversationAgentRole.personal &&
      complexity.eligibleForSocialPrompt &&
      (isGreetingLikeMessage(msgText) ||
          (isSocialReactionMessage(msgText) &&
              !(routing?.reasons.contains(productMentionedWithoutCommerce) ??
                  false)));
  // R5-PROMPT-ECO-01 — la pregunta por la actividad/estado del dueño
  // JAMÁS usa el social mínimo: su regla de honestidad vive en la regla
  // 6 del prompt completo (evidencia 16:58:17: "como estas?" recibió el
  // social con la frase LIVE STATE copiable y el 1.5B la devolvió como
  // reply "No sabes ahora, ¿qué pasó?" — despachado al cliente).
  final socialOrPendingReply =
      social &&
      !(routing?.pendingReply ?? false) &&
      !isLiveStateQuestion(msgText);
  final temporalBlock = TemporalLocationContext.promptBlock();
  final agentContract = conversationAgentContract(agentId);
  final genSw = Stopwatch()..start();
  final prompt = socialOrPendingReply
      ? conversationSocialPromptFor(
          text: msgText,
          style:
              agentId == ConversationAgentId.personal && writer._styleEnabled()
              ? writer._styleText()
              : null,
          persona: persona,
          tone: tone,
          history: formatConversationHistory(socialEntries),
          temporalContext: temporalBlock,
          agentContract: agentContract,
        )
      : conversationAgentPromptFor(
          history: history,
          text: msgText,
          style:
              agentId == ConversationAgentId.personal && writer._styleEnabled()
              ? writer._styleText()
              : null,
          business: business,
          tone: tone,
          persona: persona,
          clientContext: clientContext,
          temporalContext: temporalBlock,
          agentContract: agentContract,
        );

  return _PreparedDraftPrompt(
    messageText: msgText,
    prompt: prompt,
    sessionId: turnSession,
    isSocial: socialOrPendingReply,
    persona: persona,
    stopwatch: genSw,
  );
}
