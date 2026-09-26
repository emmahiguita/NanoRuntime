part of 'conversation_decision_engine.dart';

// QUÉ HACE: Revisa si la respuesta usa hechos verificados y cubre el turno recibido.
// CÓMO FUNCIONA: Evalúa riesgo factual y deja motivos y confianza para el cierre.
// POR QUÉ: Permite mantener las reglas legibles sin duplicar políticas.
final class _ConversationReview {
  double confidence = 0.85;
  List<String> reasons = const [];
}

ConversationDecision? _reviewConversationReply({
  required ConversationUnderstanding understanding,
  required ConversationDecisionContext context,
  required _ConversationReview review,
}) {
  final reasons = <String>[];
  final replyFold = ConversationDecisionGuards.fold(understanding.reply.trim());
  final userFold = ConversationDecisionGuards.fold(context.userText.trim());
  final isReciprocal = const [
    'y tu',
    'y vos',
    'y usted',
    'que tal tu',
    'todo bien',
    'como vas',
    'como estas',
  ].any(userFold.contains);

  if (replyFold.startsWith('hola') &&
      replyFold.contains('?') &&
      !isGreetingLikeMessage(context.userText) &&
      !isReciprocal) {
    reasons.add('saludo fuera de turno (pregunta-saludo sin saludo previo)');
    return ConversationDecision(
      disposition: ConversationDisposition.holdForApproval,
      risk: ConversationRisk.medium,
      confidence: 0.35,
      reasons: reasons,
      action: DialogueDecisionAction.prepareDraft,
    );
  }

  var confidence = 0.85;

  confidence -= _repeatedContactNamePenalty(
    senderName: context.senderName,
    reply: understanding.reply,
    reasons: reasons,
  );

  // Acción requerida con o sin hechos.
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

  // Evidencia verificada (SQLite PersonalMemory / Readability) vs hecho personal sin confirmar.
  if (understanding.intent == 'personal_appointment_unverified' ||
      understanding.intent == 'personal_project_unverified') {
    reasons.add(
      'hecho personal no verificado en SQLite (${understanding.intent}): requiere confirmación del dueño',
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
    reasons.add(
      'evidencia verificada por herramienta (${understanding.intent})',
    );
    confidence = (confidence + 0.05).clamp(0.0, 0.95);
  }

  // Hechos faltantes: pregunta legítima vs afirmación riesgosa.
  if (understanding.missingFacts.isNotEmpty) {
    if (ConversationDecisionGuards.isAsking(understanding.reply)) {
      reasons.add('missingFacts + pregunta: pide el dato faltante al cliente');
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

  // Verificación de cobertura de obligaciones en turno complejo.
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
  } else if (understanding.questions.length >= 2) {
    reasons.add('múltiples preguntas sin tipar: se degrada ligeramente');
    confidence -= 0.05;
  }

  // Datos en vivo del dueño (ubicación física actual / actividad).
  final admitsUnknownFact =
      replyFold.contains('no se') ||
      replyFold.contains('no lo se') ||
      replyFold.contains('no estoy seguro') ||
      replyFold.contains('no estoy segura') ||
      replyFold.contains('todavia no') ||
      replyFold.contains('aun no');
  if (!admitsUnknownFact &&
      requiresOwnerLiveFact(
        messageText: context.userText,
        detectedIntent: understanding.intent,
      )) {
    reasons.add('LIVE OWNER FACT: falta fuente factual del dueño');
    return ConversationDecision(
      disposition: ConversationDisposition.holdForApproval,
      risk: ConversationRisk.high,
      confidence: confidence - 0.45,
      reasons: reasons,
      action: DialogueDecisionAction.requestOwnerFact,
    );
  }

  if (understanding.intent.isEmpty) {
    if (isGreetingLikeMessage(context.userText) ||
        isSocialReactionMessage(context.userText) ||
        isLooseLaughterMessage(context.userText)) {
      reasons.add('intent ausente en turno social corto: reply válido');
    } else {
      reasons.add('intent ausente: salida posiblemente truncada');
      confidence -= 0.2;
    }
  }

  if (understanding.relation == 'corrige' ||
      understanding.relation == 'rechaza') {
    if (ConversationDecisionGuards.isAsking(understanding.reply)) {
      reasons.add(
        'relation=${understanding.relation} + pregunta: reparación honesta',
      );
      confidence -= 0.15;
    } else {
      reasons.add(
        'relation=${understanding.relation} + afirmación: contexto deshecho',
      );
      return ConversationDecision(
        disposition: ConversationDisposition.holdForApproval,
        risk: ConversationRisk.medium,
        confidence: confidence - 0.15,
        reasons: reasons,
        action: DialogueDecisionAction.askClarification,
      );
    }
  }

  review.confidence = confidence;
  review.reasons = reasons;
  return null;
}
