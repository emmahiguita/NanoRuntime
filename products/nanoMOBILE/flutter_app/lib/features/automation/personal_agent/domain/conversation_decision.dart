/// PERSONA-DECISION-02 — tipos de la decisión conversacional.
///
/// La confianza NUNCA la genera el LLM: sale de señales verificables del
/// entendimiento y del contexto de ownership (el engine aplica una fórmula
/// fija documentada). El modelo propone texto; el engine decide si se envía,
/// se retiene para aprobación o pasa al humano.
library;

import 'conversation_agent_role.dart';
import 'conversation_autonomy_mode.dart';
import '../../engine/messaging/conversation_agent.dart';

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

  /// WA-LIVE-STATE-REPAIR-01 — Reparación determinista de calidad sin LLM
  /// (live-state, muletilla de call-center en personal).
  qualityRepair,
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

  /// AUTO-03 — tope global de autonomía del pipeline.
  /// AUTONOMY FAIL-SAFE (PROD-02): default `safeAuto` — un caller sin modo
  /// explícito (fallback del dispatcher sin closure de context) jamás
  /// opera en FULL AUTONOMOUS. El coordinator SIEMPRE pasa el modo
  /// resuelto desde settings.
  final ConversationAutonomyMode autonomyMode;

  /// AUTO-02 — especialización que atiende el turno. Default `general`:
  /// sin señales, la fórmula no cambia.
  final ConversationAgentRole agentRole;

  /// Agente propietario persistente de la conversación. A diferencia de
  /// [agentRole], no cambia por el contenido de un turno.
  final ConversationAgentId agentId;

  /// P0-NO-CALLCENTER — texto del mensaje del cliente (para el guard de
  /// saludo + identidad "Soy Nano"). '' = callers legacy sin texto.
  final String userText;

  /// A11 NAME-OVERUSE — remitente factual de la notificación (jamás lo
  /// decide el LLM): el gate de nombre repetido solo corre cuando existe.
  /// '' = callers legacy sin remitente.
  final String senderName;

  const ConversationDecisionContext({
    this.humanOwnsConversation = false,
    this.identityConfidence = 1.0,
    this.autonomyMode = ConversationAutonomyMode.safeAuto,
    this.agentRole = ConversationAgentRole.general,
    this.agentId = ConversationAgentId.personal,
    this.userText = '',
    this.senderName = '',
  });
}

/// Categorías de decisión conversacional (Taxonomía de 13 acciones).
enum DialogueDecisionAction {
  /// Enviar respuesta inmediata (confianza alta, fast path o LLM seguro).
  replyNow,

  /// Agrupar ráfagas en cola (BurstTurnGate activo).
  wait,

  /// Mensaje duplicado o sin efecto (EventDedupeStore / Eco).
  ignore,

  /// Reacción o cierre social breve sin re-preguntar.
  acknowledge,

  /// Aclaración honesta ante ambigüedad o referencia rota.
  askClarification,

  /// Preparar borrador para revisión humana (PendingReplyStore).
  prepareDraft,

  /// Notificar al usuario por asunto importante o urgencia.
  notifyOwner,

  /// Solicitar al propietario un hecho no registrado.
  requestOwnerFact,

  /// Transferir el control completo al propietario (asuntos sensibles).
  transferToOwner,

  /// (Negocios) Solicitar dato obligatorio ausente.
  askRequiredDetail,

  /// (Negocios) Recomendar producto o servicio de catálogo.
  recommendProduct,

  /// (Negocios) Registrar transacción u operación confirmada.
  executeOperation,

  /// Cierre de flujo comercial o tema.
  closeFlow,
}

final class ConversationDecision {
  final ConversationDisposition disposition;
  final ConversationRisk risk;

  /// Acción específica determinada dentro de la taxonomía de 13 opciones.
  final DialogueDecisionAction action;

  /// Confianza derivada SOLO de señales verificables (0..1). Fórmula fija
  /// del engine — jamás un número emitido por el modelo.
  final double confidence;

  /// Razones legibles (traza logcat `[decision]`): cada señal aplicada.
  final List<String> reasons;

  /// WA-LIVE-STATE-REPAIR-01 — texto corregido deterministamente cuando
  /// disposition == qualityRepair.
  final String? repairedText;

  const ConversationDecision({
    required this.disposition,
    required this.risk,
    required this.confidence,
    required this.reasons,
    this.action = DialogueDecisionAction.replyNow,
    this.repairedText,
  });

  bool get autoSend =>
      disposition == ConversationDisposition.autoSend ||
      (disposition == ConversationDisposition.qualityRepair &&
          repairedText != null &&
          repairedText!.trim().isNotEmpty);
}
