/// PERSONA-DECISION-02 — tipos de la decisión conversacional.
///
/// La confianza NUNCA la genera el LLM: sale de señales verificables del
/// entendimiento y del contexto de ownership (el engine aplica una fórmula
/// fija documentada). El modelo propone texto; el engine decide si se envía,
/// se retiene para aprobación o pasa al humano.
library;

import 'conversation_agent_role.dart';
import 'conversation_autonomy_mode.dart';

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

/// Contexto externo de la decisión. PERSONA-HANDOFF-03 lo alimenta con el
/// ownership durable por conversación; PERSONA-AUTONOMY-11 añade la
/// confianza de identidad (misma evidencia del pipeline); AUTO-03 añade el
/// modo de autonomía y AUTO-02 el rol de especialización del turno.
final class ConversationDecisionContext {
  /// true = el humano declaró control de ESTA conversación: el bot puede
  /// preparar drafts pero jamás envía sin que el dueño los suelte.
  final bool humanOwnsConversation;

  /// Confianza de la identidad de la conversación (ConversationIdentity,
  /// 0..1). 1.0 por defecto = callers sin evidencia de identidad conservan
  /// la paridad; el pipeline real la alimenta con la evidencia de Android.
  final double identityConfidence;

  /// AUTO-03 — tope global de autonomía del pipeline. Default `autonomous`
  /// = la fórmula del engine queda EXACTAMENTE como antes (paridad).
  final ConversationAutonomyMode autonomyMode;

  /// AUTO-02 — especialización que atiende el turno. Default `general`:
  /// sin señales, la fórmula no cambia.
  final ConversationAgentRole agentRole;

  /// P0-NO-CALLCENTER — texto del mensaje del cliente (para el guard de
  /// saludo + identidad "Soy Nano"). '' = callers legacy sin texto.
  final String userText;

  const ConversationDecisionContext({
    this.humanOwnsConversation = false,
    this.identityConfidence = 1.0,
    this.autonomyMode = ConversationAutonomyMode.autonomous,
    this.agentRole = ConversationAgentRole.general,
    this.userText = '',
  });
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
