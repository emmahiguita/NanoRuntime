part of 'notification_draft_writer.dart';

// QUÉ HACE: Resuelve historial, agente, rol y persona para el mensaje recibido.
// CÓMO FUNCIONA: Usa memoria observada y el router de dominio ya configurado.
// POR QUÉ: Aísla la lectura contextual del armado del prompt.
final class _ResolvedDraftContext {
  const _ResolvedDraftContext({
    required this.messageText,
    required this.historyEntries,
    required this.socialEntries,
    required this.history,
    required this.routing,
    required this.agentId,
    required this.role,
    required this.persona,
    required this.liveEvidence,
    required this.activeTopic,
    required this.canonicalHistory,
    required this.historyNotice,
  });

  final String messageText;
  final List<ConversationMemoryEntry> historyEntries;
  final List<ConversationMemoryEntry> socialEntries;
  final String history;
  final bool canonicalHistory;
  final String historyNotice;
  final ConversationAgentRouting? routing;
  final ConversationAgentId agentId;
  final ConversationAgentRole role;
  final String persona;
  final PersonalLiveEvidence liveEvidence;

  /// LOOP-3 — tema activo resuelto de la memoria conversacional (metadata
  /// compacta; alimenta el estado personal sin persistir transcripciones).
  final String activeTopic;
}

Future<_ResolvedDraftContext> _resolveDraftContext(
  RuntimeNotificationDraftWriter writer,
  NotificationObject notification,
  String conversationId,
) async {
  // MSG-TEXT-01 — fuente canónica: interpretableText prefiere messageText
  // (texto individual del MessagingStyle) sobre text (resumen/agregado).
  // Para párrafos largos messageText contiene el mensaje completo; text
  // puede estar truncado o ser el acumulado de varios mensajes.
  final msgText = notification.interpretableText;
  // La percepción es evidencia para redactar; no cambia intención/fecha/persona.
  final sourceText = notification.requestText;
  // La identidad visible y el shortcut/JID pueden variar para el mismo
  // chat. El resolver une únicamente memoria factual observada por Nano y
  // quita el mensaje actual, que ya entra por separado en el prompt.
  final resolvedMemory = await ConversationDurableContext.resolve(
    store: writer._memory,
    conversationId: conversationId,
    notification: notification,
  );
  // El resolver ya eligió UNA fuente. Todas las rutas usan estas entradas;
  // no relee SQLite ni sustituye la ventana por memoria antigua en el prompt local.
  final historyEntries = resolvedMemory?.entries ?? const [];
  final canonicalHistory = resolvedMemory?.canonicalHistory ?? false;
  final historyNotice = resolvedMemory?.historyNotice ?? '';
  // Una corrección se ancla al último envío observado, sin inventar recuerdos.
  final history = historyEntries.isEmpty
      ? '(sin historial previo)'
      : !canonicalHistory && isCorrectionMessage(msgText)
      ? _correctionAnchor(historyEntries)
      : formatConversationHistory(
          historyEntries,
          currentText: sourceText,
          currentSender: notification.sender,
          activeTopic: resolvedMemory?.activeTopic,
        );
  // CONV-SOC-01 — ventana social relevante basada en participantes,
  // relación, tema, entidades, continuidad, intención y recencia.
  final socialEntries = socialConversationWindow(
    historyEntries,
    currentText: sourceText,
    currentSender: notification.sender,
    activeTopic: resolvedMemory?.activeTopic,
  );
  // P0-ROUTE — UNDERSTANDING → ROUTER → CONTEXT: el rol decide QUÉ
  // contexto entra al prompt. Antes negocio y persona entraban por
  // match léxico independiente del routing: una broma con "crema
  // alpina" recibía <DATOS DEL NEGOCIO> y respondía stock (evidencia
  // física). Ahora el invariante manda: SIN intención comercial NO hay
  // bloque comercial; persona+relación SOLO en turnos personales
  // (incluida identidad y correcciones). null routing = legacy.
  final routing = writer._routeFor?.call(
    conversationId,
    sourceText,
    notification.sender,
    notification.packageName,
  );
  final agentId =
      writer._agentFor?.call(conversationId, notification.packageName) ??
      ConversationAgentId.defaultFor(
        channel: notification.packageName,
        appPackage: notification.packageName,
      );
  final routedRole = routing?.role ?? ConversationAgentRole.general;
  final role = switch (agentId) {
    ConversationAgentId.personal => ConversationAgentRole.personal,
    ConversationAgentId.business =>
      routedRole == ConversationAgentRole.personal
          ? ConversationAgentRole.general
          : routedRole,
  };
  debugPrint(
    '[route] agente=${agentId.name} rol=${role.name} '
    'commercial=${routing?.commercialIntent == true} '
    '${routing?.reasons.join(' | ') ?? 'legacy (sin router)'}',
  );
  // PERSONA-COMPOSE-08 — bloque persona antes del prompt (FTS4 local,
  // no consume turno del motor). Sin perfil ni ejemplos: cadena vacía y
  // el prompt queda idéntico al de WA-CTX-01.
  // El builder entrega estilo compacto en charla y datos vigentes en preguntas personales.
  final persona = agentId == ConversationAgentId.personal
      ? await writer._personaBlock?.call(
              conversationId,
              sourceText,
              notification.sender,
              role.name,
            ) ??
            ''
      : '';

  // Se consulta una vez por turno; nunca comparte ubicación ni texto entre chats.
  final liveEvidence = agentId == ConversationAgentId.personal
      ? await writer._liveContext.resolve(
          sourceText,
          historyEntries
              .where(
                (entry) => entry.kind == ConversationMemoryEntryKind.inbound,
              )
              .map((entry) => entry.text)
              .toList(),
          scopeId: conversationId,
        )
      : const PersonalLiveEvidence();

  return _ResolvedDraftContext(
    messageText: msgText,
    historyEntries: historyEntries,
    socialEntries: socialEntries,
    history: history,
    canonicalHistory: canonicalHistory,
    historyNotice: historyNotice,
    routing: routing,
    agentId: agentId,
    role: role,
    persona: persona,
    liveEvidence: liveEvidence,
    activeTopic: resolvedMemory?.activeTopic ?? '',
  );
}
