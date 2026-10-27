part of 'conversation_decision_safety.dart';

// QUÉ HACE: comprueba afirmaciones presentes contra la actividad vigente concreta.
// CÓMO FUNCIONA: tener agenda no prueba cualquier actividad; trabajo no valida
//               almuerzo. Preguntas, relatos ajenos y negaciones no son hechos propios.
// POR QUÉ: Evita reemplazar respuestas naturales del modelo o retener turnos válidos
//          cuando el modelo conversa normalmente o hace preguntas de vuelta.
ConversationDecision? _evaluateLiveStateSafety({
  required ConversationUnderstanding understanding,
  required ConversationDecisionContext context,
  required bool callCenterTurn,
  required bool allowRepair,
  required ConversationDecision Function({
    required ConversationUnderstanding understanding,
    required ConversationDecisionContext context,
    required bool allowRepair,
  })
  decider,
}) {
  // Una nota o actividad futura no valida la afirmación presente del modelo.
  if (OwnerActivityEvidence.supports(
    understanding.reply,
    context.ownerCurrentActivities,
  )) {
    return null;
  }

  final liveStateTurn = isLiveStateQuestion(context.userText);
  if (!liveStateTurn && !callCenterTurn) return null;

  if (!ConversationDecisionGuards.affirmsOwnerActivity(understanding.reply)) {
    return null;
  }

  final repaired = safeConversationRepair.repair(
    RepairCase.liveStateAffirmed,
    reply: understanding.reply,
    userText: context.userText,
    senderName: context.senderName,
  );
  if (allowRepair &&
      repaired != null &&
      repaired.trim() != understanding.reply.trim()) {
    return ConversationDecisionRepairValidator.validate(
      understanding: understanding,
      context: context,
      repaired: repaired,
      reason:
          'calidad reparada: LIVE STATE actividad afirmada corregida a respuesta honesta',
      decider: decider,
    );
  }

  return const ConversationDecision(
    disposition: ConversationDisposition.holdForApproval,
    risk: ConversationRisk.medium,
    confidence: 0.3,
    reasons: ['estado temporal histórico sin evidencia presente verificada'],
    action: DialogueDecisionAction.prepareDraft,
  );
}
