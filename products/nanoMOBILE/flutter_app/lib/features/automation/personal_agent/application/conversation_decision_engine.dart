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

    final reasons = <String>[];
    final replyFold = ConversationDecisionGuards.fold(understanding.reply.trim());
    final userFold = ConversationDecisionGuards.fold(context.userText.trim());
    final isReciprocal = const [
      'y tu', 'y vos', 'y usted', 'que tal tu', 'todo bien', 'como vas', 'como estas'
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

    // Repetición innecesaria del nombre del contacto.
    if (context.senderName.trim().isNotEmpty) {
      final name = ConversationDecisionGuards.fold(context.senderName.trim());
      if (name.length >= 3) {
        final matches = RegExp('\\b${RegExp.escape(name)}\\b')
            .allMatches(ConversationDecisionGuards.fold(understanding.reply))
            .length;
        if (matches >= 2) {
          reasons.add('nombre del contacto repetido sin función ($matches×)');
          confidence -= 0.15;
        }
      }
    }

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
        reasons.add('todas las obligaciones atendidas (${understanding.obligations.length})');
      } else {
        reasons.add('obligaciones incompletas (${understanding.coveredObligationCount}/${understanding.obligations.length})');
        confidence -= 0.15;
      }
    } else if (understanding.questions.length >= 2) {
      reasons.add('múltiples preguntas sin tipar: se degrada ligeramente');
      confidence -= 0.05;
    }

    // Datos en vivo del dueño (ubicación física actual).
    if (requiresOwnerLiveFact(messageText: context.userText, detectedIntent: understanding.intent)) {
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

    if (understanding.relation == 'corrige' || understanding.relation == 'rechaza') {
      if (ConversationDecisionGuards.isAsking(understanding.reply)) {
        reasons.add('relation=${understanding.relation} + pregunta: reparación honesta');
        confidence -= 0.15;
      } else {
        reasons.add('relation=${understanding.relation} + afirmación: contexto deshecho');
        return ConversationDecision(
          disposition: ConversationDisposition.holdForApproval,
          risk: ConversationRisk.medium,
          confidence: confidence - 0.15,
          reasons: reasons,
          action: DialogueDecisionAction.askClarification,
        );
      }
    }

    final risk = confidence >= 0.75
        ? ConversationRisk.low
        : confidence >= 0.6
            ? ConversationRisk.medium
            : ConversationRisk.high;

    if (confidence < 0.6 ||
        (context.autonomyMode == ConversationAutonomyMode.safeAuto &&
            (risk != ConversationRisk.low || understanding.missingFacts.isNotEmpty)) ||
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

    final isSocialAcknowledge = isGreetingLikeMessage(context.userText) ||
        isSocialReactionMessage(context.userText) || isLooseLaughterMessage(context.userText);

    return ConversationDecision(
      disposition: ConversationDisposition.autoSend,
      risk: risk,
      confidence: confidence,
      reasons: reasons,
      action: isSocialAcknowledge ? DialogueDecisionAction.acknowledge : DialogueDecisionAction.replyNow,
    );
  }
}
