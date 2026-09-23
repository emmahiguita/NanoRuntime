// conversation_decision_repair_validator.dart
//
// QUÉ HACE:
// Valida reparaciones deterministas generadas para el diálogo del Agente Personal.
//
// CÓMO FUNCIONA:
// - Construye un candidato [ConversationUnderstanding] con el texto reparado.
// - Vuelve a evaluar las guardas de calidad con `allowRepair: false` para evitar ciclos infinitos.
// - Retorna una decisión final asegurando que si el modo es `suggestions`, se mantenga retenido para revisión humana.
//
// POR QUÉ:
// Desacopla la lógica de validación circular de reparaciones (SOLID - SRP),
// garantizando que los archivos del motor permanezcan por debajo de 200 líneas.

library;

import '../../engine/notifications/conversation_understanding.dart';
import '../domain/conversation_autonomy_mode.dart';
import '../domain/conversation_decision.dart';

abstract final class ConversationDecisionRepairValidator {
  static ConversationDecision validate({
    required ConversationUnderstanding understanding,
    required ConversationDecisionContext context,
    required String repaired,
    required String reason,
    required ConversationDecision Function({
      required ConversationUnderstanding understanding,
      required ConversationDecisionContext context,
      required bool allowRepair,
    }) decider,
  }) {
    final candidate = ConversationUnderstanding(
      intent: understanding.intent,
      relation: understanding.relation,
      questions: understanding.questions,
      missingFacts: understanding.missingFacts,
      requiresAction: understanding.requiresAction,
      reply: repaired.trim(),
    );
    final validated = decider(
      understanding: candidate,
      context: context,
      allowRepair: false,
    );
    final isApproved = validated.autoSend ||
        (context.autonomyMode == ConversationAutonomyMode.suggestions &&
            validated.disposition == ConversationDisposition.holdForApproval &&
            validated.confidence >= 0.6);

    return ConversationDecision(
      disposition: isApproved
          ? (context.autonomyMode == ConversationAutonomyMode.suggestions
              ? ConversationDisposition.holdForApproval
              : ConversationDisposition.qualityRepair)
          : validated.disposition,
      risk: validated.risk,
      confidence: validated.confidence,
      reasons: [reason, ...validated.reasons],
      repairedText: isApproved ? candidate.reply : null,
    );
  }
}
