part of 'conversation_decision_safety.dart';

// QUÉ HACE: Bloquea hechos actuales del dueño cuando no hay evidencia verificable.
// CÓMO FUNCIONA: Acepta desconocimiento seguro, intenta reparar o retiene el borrador.
// POR QUÉ: Evita enviar actividad o ubicación inventada en conversaciones personales.
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
  // 8. Invariante transversal (Ciclos 7 y 20): Ningún turno personal puede afirmar
  // estado actual del dueño (niveles 1-2) sin evidencia viva verificada, sin importar
  // si proviene de PersonaStyleMatch, FastPath, LLM o Repair.
  final liveStateTurn = isLiveStateQuestion(context.userText);
  final unverifiedStyleActivity =
      callCenterTurn &&
      ConversationDecisionGuards.affirmsOwnerActivity(understanding.reply);
  if (liveStateTurn || unverifiedStyleActivity) {
    final r = ConversationDecisionGuards.fold(understanding.reply);
    final admitsUnknown =
        r.contains('no se') ||
        r.contains('no lo se') ||
        r.contains('no estoy seguro') ||
        r.contains('no estoy segura');
    // Admitir desconocimiento solo es suficiente si la frase no añade una
    // actividad afirmada ("no sé, estoy en casa" sigue siendo un hecho).
    final safeUnknown =
        admitsUnknown &&
        !ConversationDecisionGuards.affirmsOwnerActivity(understanding.reply);
    if (!safeUnknown) {
      if (liveStateTurn &&
          ConversationDecisionGuards.isAsking(understanding.reply)) {
        final repaired = safeConversationRepair.repair(
          RepairCase.liveStateQuestionMirror,
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
                'calidad reparada: LIVE STATE question mirror corregido a respuesta honesta',
            decider: decider,
          );
        }
      }
      if (ConversationDecisionGuards.affirmsOwnerActivity(
        understanding.reply,
      )) {
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
          reasons: [
            'estado temporal histórico sin evidencia presente verificada',
          ],
          action: DialogueDecisionAction.prepareDraft,
        );
      }
    }
  }

  return null;
}
