/// QUÉ HACE: Motor de decisión determinista para el Agente Personal (FACTS → DECISION → SEND).
/// CÓMO FUNCIONA: Evalúa precondiciones duras (safety), cobertura de obligaciones, penaliza
/// alucinaciones o datos faltantes y pondera confianza para decidir si auto-enviar o retener.
/// POR QUÉ: Asegura que el bot jamás afirme datos que desconoce ni envíe respuestas incompletas (<200 líneas).
library;

import '../../engine/notifications/conversation_understanding.dart';
import '../domain/conversation_agent_role.dart';
import '../domain/conversation_autonomy_mode.dart';
import '../domain/conversation_decision.dart';
import '../domain/owner_live_fact_guard.dart' show requiresOwnerLiveFact;
import 'conversation_decision_guards.dart';
import 'conversation_decision_safety.dart';

export 'conversation_decision_guards.dart';

part 'conversation_decision_review.part.dart';
part 'conversation_decision_engine_finish.part.dart';
part 'conversation_decision_name_guard.part.dart';

final class ConversationDecisionEngine {
  const ConversationDecisionEngine();

  ConversationDecision decide({
    required ConversationUnderstanding understanding,
    ConversationDecisionContext context = const ConversationDecisionContext(),
  }) => _decide(
    understanding: understanding,
    context: context,
    allowRepair: true,
  );

  ConversationDecision _decide({
    required ConversationUnderstanding understanding,
    required ConversationDecisionContext context,
    required bool allowRepair,
  }) {
    final safetyEarlyExit = ConversationDecisionSafety.evaluatePreconditions(
      understanding: understanding,
      context: context,
      allowRepair: allowRepair,
      decider: _decide,
    );
    if (safetyEarlyExit != null) return safetyEarlyExit;

    final review = _ConversationReview();
    final earlyDecision = _reviewConversationReply(
      understanding: understanding,
      context: context,
      review: review,
    );
    if (earlyDecision != null) return earlyDecision;
    return _finishConversationDecision(
      understanding: understanding,
      context: context,
      confidence: review.confidence,
      reasons: review.reasons,
    );
  }
}
