// conversation_reply_composer_models.dart
//
// QUÉ HACE:
// Define los contratos, modelos de datos y empaquetador para la composición de respuestas conversacionales
// (`ConversationDraftResult`, `packConversationDraftResult` y la interfaz `ConversationReplyComposer`).
//
// CÓMO FUNCIONA:
// - `ConversationDraftResult` transporta la respuesta final sanitizada, comprensión NLU,
//   decisión de autonomía, sugerencias interactivas y flags de ruta rápida / reparación.
// - `packConversationDraftResult` normaliza sugerencias, limpia caracteres no permitidos y
//   aplica salvaguardas de call center si faltan opciones interactivas.
//
// POR QUÉ:
// Aplica ISP y SRP desacoplando contratos y utilidades de empaque, asegurando archivos < 130 líneas.

library;

import '../language/language_assist.dart';
import '../notifications/conversation_understanding.dart';
import '../notifications/notification_object.dart';
import '../../personal_agent/application/conversation_decision_engine.dart';
import '../../personal_agent/domain/conversation_agent_role.dart';
import '../../personal_agent/domain/conversation_decision.dart';

/// Resultado estructurado de la composición de respuesta conversacional.
final class ConversationDraftResult {
  final String text;
  final ConversationUnderstanding understanding;
  final ConversationDecision decision;
  final ConversationAgentRole role;
  final String conversationId;
  final bool isFastPath;
  final bool isRepaired;
  final List<String> suggestions;

  const ConversationDraftResult({
    required this.text,
    required this.understanding,
    required this.decision,
    required this.role,
    required this.conversationId,
    this.suggestions = const [],
    this.isFastPath = false,
    this.isRepaired = false,
  });

  bool get hasReply => text.trim().isNotEmpty;
}

/// Contrato único de composición conversacional para la aplicación.
abstract interface class ConversationReplyComposer {
  Future<ConversationDraftResult?> compose(
    NotificationObject notification, {
    ConversationDecisionContext? decisionContext,
  });

  Future<List<String>> composeSuggestions(
    NotificationObject notification, {
    int maxSuggestions = 3,
    ConversationDecisionContext? decisionContext,
  });
}

/// Empaqueta, sanitiza y arbitra (Generation -> Ranking -> Factual Validation -> Repair -> Revalidation -> Governance).
ConversationDraftResult packConversationDraftResult({
  required String reply,
  required ConversationUnderstanding understanding,
  required List<String> suggestions,
  required ConversationDecisionContext context,
  required String conversationId,
  required bool isFastPath,
  required ConversationDecisionEngine decisionEngine,
}) {
  final cleaned = LanguageAssistService.safeCleanOutput(reply).trim();
  final candidateUnderstanding = understanding.reply.trim() == cleaned
      ? understanding
      : ConversationUnderstanding(
          intent: understanding.intent,
          relation: understanding.relation,
          options: understanding.options,
          questions: understanding.questions,
          missingFacts: understanding.missingFacts,
          obligations: understanding.obligations,
          requiresAction: understanding.requiresAction,
          reply: cleaned,
        );
  final decision = decisionEngine.decide(
    understanding: candidateUnderstanding,
    context: context,
  );
  final isRepaired =
      decision.repairedText != null && decision.repairedText!.trim().isNotEmpty;
  final finalText = isRepaired
      ? LanguageAssistService.safeCleanOutput(decision.repairedText!).trim()
      : cleaned;

  final resultSuggestions = <String>[];
  if (finalText.isNotEmpty) resultSuggestions.add(finalText);
  for (final s in suggestions) {
    final cleanS = LanguageAssistService.safeCleanOutput(s).trim();
    if (cleanS.isNotEmpty && !resultSuggestions.contains(cleanS)) {
      resultSuggestions.add(cleanS);
    }
    if (resultSuggestions.length >= 3) break;
  }

  return ConversationDraftResult(
    text: finalText,
    understanding: candidateUnderstanding,
    decision: decision,
    role: context.agentRole,
    conversationId: conversationId,
    suggestions: resultSuggestions,
    isFastPath: isFastPath,
    isRepaired: isRepaired,
  );
}
