part of 'conversation_decision_engine.dart';

/// Resultado intermedio de la evaluación de confianza del turno.
final class _ConversationReview {
  double confidence = 0.85;
  List<String> reasons = const [];
}

/// Revisa si la respuesta generada es segura para envío según el modo activo.
///
/// - **QUÉ HACE:** Evalúa señales de acción requerida, hechos faltantes y
///   preguntas directas sobre ubicación/actividad física del dueño.
/// - **CÓMO FUNCIONA:** No bloquea saludos espontáneos ni respuestas naturales
///   cotidianas; solo retiene cuando el contacto preguntó explícitamente por
///   estado/ubicación en vivo sin cronograma activo y el modelo inventó una
///   actividad física concreta.
/// - **POR QUÉ:** Evita que Nano retenga respuestas legítimas y deje al
///   interlocutor sin contestación.
ConversationDecision? _reviewConversationReply({
  required ConversationUnderstanding understanding,
  required ConversationDecisionContext context,
  required _ConversationReview review,
}) {
  final reasons = <String>[];
  final replyFold = ConversationDecisionGuards.fold(understanding.reply.trim());
  var confidence = 0.85;

  confidence -= _repeatedContactNamePenalty(
    senderName: context.senderName,
    reply: understanding.reply,
    reasons: reasons,
  );

  if (understanding.requiresAction && understanding.missingFacts.isNotEmpty) {
    reasons.add('requiresAction: el modelo pide acción fuera de su alcance');
    return ConversationDecision(
      disposition: ConversationDisposition.needsHuman,
      risk: ConversationRisk.high,
      confidence: confidence - 0.5,
      reasons: reasons,
      action: DialogueDecisionAction.notifyOwner,
    );
  }
  if (understanding.requiresAction) {
    reasons.add('requiresAction sin missingFacts: señal incoherente');
    confidence -= 0.1;
  }

  if (understanding.intent == 'personal_appointment_unverified' ||
      understanding.intent == 'personal_project_unverified') {
    reasons.add(
      'hecho personal no verificado (${understanding.intent}): requiere confirmación',
    );
    return ConversationDecision(
      disposition: ConversationDisposition.holdForApproval,
      risk: ConversationRisk.medium,
      confidence: 0.55,
      reasons: reasons,
      action: DialogueDecisionAction.requestOwnerFact,
    );
  }

  if (understanding.intent == 'coreference_clarification' ||
      understanding.intent == 'coreference_disambiguation') {
    reasons.add('desambiguación referencial honesta (${understanding.intent})');
    return ConversationDecision(
      disposition: context.autonomyMode == ConversationAutonomyMode.suggestions
          ? ConversationDisposition.holdForApproval
          : ConversationDisposition.autoSend,
      risk: ConversationRisk.low,
      confidence: 0.82,
      reasons: reasons,
      action: DialogueDecisionAction.askClarification,
    );
  }

  if ((understanding.intent == 'personal_memory_verified' ||
          understanding.intent == 'coreference_resolved' ||
          understanding.intent == 'external_knowledge_styled') &&
      understanding.missingFacts.isEmpty) {
    reasons.add('evidencia verificada (${understanding.intent})');
    confidence = (confidence + 0.05).clamp(0.0, 0.95);
  }

  if (understanding.missingFacts.isNotEmpty) {
    if (ConversationDecisionGuards.isAsking(understanding.reply)) {
      reasons.add('missingFacts + pregunta: pide el dato faltante');
      confidence -= 0.10;
    } else {
      reasons.add('missingFacts + afirmación: riesgo de alucinación');
      return ConversationDecision(
        disposition: ConversationDisposition.holdForApproval,
        risk: ConversationRisk.medium,
        confidence: confidence - 0.4,
        reasons: reasons,
        action: DialogueDecisionAction.requestOwnerFact,
      );
    }
  }

  if (understanding.obligations.isNotEmpty) {
    if (understanding.allObligationsCovered) {
      reasons.add(
        'todas las obligaciones atendidas (${understanding.obligations.length})',
      );
    } else {
      reasons.add(
        'obligaciones incompletas (${understanding.coveredObligationCount}/${understanding.obligations.length})',
      );
      confidence -= 0.15;
    }
  }

  final admitsUnknownFact =
      replyFold.contains('no se') ||
      replyFold.contains('no lo se') ||
      replyFold.contains('no estoy seguro') ||
      replyFold.contains('no estoy segura') ||
      replyFold.contains('todavia no') ||
      replyFold.contains('aun no');
  final affirmsActivity = ConversationDecisionGuards.affirmsOwnerActivity(
    understanding.reply,
  );
  if (!OwnerActivityEvidence.supports(
        understanding.reply,
        context.ownerCurrentActivities,
      ) &&
      !admitsUnknownFact &&
      affirmsActivity &&
      isLiveStateQuestion(context.userText) &&
      requiresOwnerLiveFact(
        messageText: context.userText,
        detectedIntent: understanding.intent,
        availableEvidence: FactualEvidenceLevel.contextualHistoricalMemory,
      )) {
    reasons.add('LIVE OWNER FACT: actividad física afirmada sin agenda activa');
    return ConversationDecision(
      disposition: ConversationDisposition.holdForApproval,
      risk: ConversationRisk.high,
      confidence: confidence - 0.45,
      reasons: reasons,
      action: DialogueDecisionAction.requestOwnerFact,
    );
  }

  if (understanding.intent.isEmpty &&
      !isGreetingLikeMessage(context.userText) &&
      !isSocialReactionMessage(context.userText) &&
      !isLooseLaughterMessage(context.userText)) {
    confidence -= 0.1;
  }

  review.confidence = confidence;
  review.reasons = reasons;
  return null;
}
