/// PERSONA-DECISION-02 — tipos de la decisión conversacional.
///
/// La confianza NUNCA la genera el LLM: sale de señales verificables del
/// entendimiento y del contexto de ownership (el engine aplica una fórmula
/// fija documentada). El modelo propone texto; el engine decide si se envía,
/// se retiene para aprobación o pasa al humano.
library;

/// Qué hacer con el draft.
enum ConversationDisposition {
  /// Enviar directo (confianza suficiente, señales limpias).
  autoSend,

  /// Retener: el draft existe pero hay riesgo — el humano aprueba antes de
  /// que salga nada.
  holdForApproval,

  /// El humano debe responder: el modelo pidió una acción fuera de su
  /// alcance o el dueño tomó el control de la conversación.
  needsHuman,
}

/// Nivel de riesgo de un envío automático.
enum ConversationRisk { low, medium, high }

/// Contexto externo de la decisión. PERSONA-HANDOFF-03 lo alimentará con el
/// ownership durable por conversación; mientras tanto el caller lo provee
/// (por defecto: el bot decide solo, paridad con el comportamiento actual).
final class ConversationDecisionContext {
  /// true = el humano declaró control de ESTA conversación: el bot puede
  /// preparar drafts pero jamás envía sin que el dueño los suelte.
  final bool humanOwnsConversation;

  const ConversationDecisionContext({this.humanOwnsConversation = false});
}

final class ConversationDecision {
  final ConversationDisposition disposition;
  final ConversationRisk risk;

  /// Confianza derivada SOLO de señales verificables (0..1). Fórmula fija
  /// del engine — jamás un número emitido por el modelo.
  final double confidence;

  /// Razones legibles (traza logcat `[decision]`): cada señal aplicada.
  final List<String> reasons;

  const ConversationDecision({
    required this.disposition,
    required this.risk,
    required this.confidence,
    required this.reasons,
  });

  bool get autoSend => disposition == ConversationDisposition.autoSend;
}
