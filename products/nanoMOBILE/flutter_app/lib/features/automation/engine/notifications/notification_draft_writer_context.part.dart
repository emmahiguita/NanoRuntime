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
  });

  final String messageText;
  final List<ConversationMemoryEntry> historyEntries;
  final List<ConversationMemoryEntry> socialEntries;
  final String history;
  final ConversationAgentRouting? routing;
  final ConversationAgentId agentId;
  final ConversationAgentRole role;
  final String persona;
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
  // La identidad visible y el shortcut/JID pueden variar para el mismo
  // chat. El resolver une únicamente memoria factual observada por Nano y
  // quita el mensaje actual, que ya entra por separado en el prompt.
  final resolvedMemory = ConversationContextResolver.resolve(
    store: writer._memory,
    conversationId: conversationId,
    notification: notification,
  );
  final historyEntries = resolvedMemory?.entries ?? const [];
  // CONTEXT-GATE-01 — saludo puro: el historial comercial anterior NO
  // entra (el 1.5B ecoea la respuesta vieja del Negro en un "Hola");
  // referencias y respuestas cortas sí necesitan la conversación.
  // R5-GREETING-01 — el saludo extendido ("hola como estas emma?")
  // limpia el historial igual que el puro: es saludo real, no
  // referencia a lo conversado.
  // P0-CORRECTION — corrección ("¿cuál negro de qué hablas?"): el
  // cliente está deshaciendo el turno anterior; el historial del tema
  // viejo solo incita eco. R5-06 — pero anclada al ÚLTIMO reply de
  // Nano: sin ancla el modelo no sabe qué corrigieron y responde
  // "¿qué quieres que haga?" (evidencia física). El saludo sigue con
  // historial limpio total.
  final history = (isPureGreeting(msgText) || historyEntries.isEmpty)
      ? '(sin historial previo)'
      : isCorrectionMessage(msgText)
      ? _correctionAnchor(historyEntries)
      : formatConversationHistory(
          historyEntries,
          currentText: msgText,
          currentSender: notification.sender,
          activeTopic: resolvedMemory?.activeTopic,
        );
  // CONV-SOC-01 — ventana social relevante basada en participantes,
  // relación, tema, entidades, continuidad, intención y recencia.
  final socialEntries = socialConversationWindow(
    historyEntries,
    currentText: msgText,
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
    msgText,
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
  final persona = agentId == ConversationAgentId.personal
      ? await writer._personaBlock?.call(
              conversationId,
              msgText,
              notification.sender,
              role.name,
            ) ??
            ''
      : '';

  return _ResolvedDraftContext(
    messageText: msgText,
    historyEntries: historyEntries,
    socialEntries: socialEntries,
    history: history,
    routing: routing,
    agentId: agentId,
    role: role,
    persona: persona,
  );
}
