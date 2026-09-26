part of 'conversation_decision_engine.dart';

// QUÉ HACE: Decide entre enviar, retener o pedir intervención humana.
// CÓMO FUNCIONA: Combina confianza, riesgo y modo de autonomía.
// POR QUÉ: Mantiene centralizada la última barrera antes de responder.
ConversationDecision _finishConversationDecision({
  required ConversationUnderstanding understanding,
  required ConversationDecisionContext context,
  required double confidence,
  required List<String> reasons,
}) {
  final risk = confidence >= 0.75
      ? ConversationRisk.low
      : confidence >= 0.6
      ? ConversationRisk.medium
      : ConversationRisk.high;

  if (confidence < 0.6 ||
      (context.autonomyMode == ConversationAutonomyMode.safeAuto &&
          (risk != ConversationRisk.low ||
              understanding.missingFacts.isNotEmpty)) ||
      context.autonomyMode == ConversationAutonomyMode.suggestions) {
    if (context.autonomyMode == ConversationAutonomyMode.suggestions) {
      reasons.add('modo sugerencias: draft retenido para aprobación');
    } else if (context.autonomyMode == ConversationAutonomyMode.safeAuto) {
      reasons.add('safeAuto: riesgo ${risk.name} o hechos faltantes');
    }
    return ConversationDecision(
      disposition: ConversationDisposition.holdForApproval,
      risk: risk,
      confidence: confidence,
      reasons: reasons,
      action: DialogueDecisionAction.prepareDraft,
    );
  }

  final isSocialAcknowledge =
      isGreetingLikeMessage(context.userText) ||
      isSocialReactionMessage(context.userText) ||
      isLooseLaughterMessage(context.userText);

  return ConversationDecision(
    disposition: ConversationDisposition.autoSend,
    risk: risk,
    confidence: confidence,
    reasons: reasons,
    action: isSocialAcknowledge
        ? DialogueDecisionAction.acknowledge
        : DialogueDecisionAction.replyNow,
  );
}
