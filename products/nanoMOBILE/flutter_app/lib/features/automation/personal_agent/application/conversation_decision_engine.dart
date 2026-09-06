/// PERSONA-DECISION-02 — motor de decisión determinista (regla fundamental:
/// FACTS → DECISION → SEND; la decisión es código, no LLM).
///
/// Señales verificables (ninguna sale del modelo):
/// - `requiresAction`: el modelo pide una acción fuera de su alcance
///   (coordinar, permiso, acción física) → humano.
/// - `missingFacts` + reply ASERTIVO: el modelo no sabe un dato y aun así
///   afirma → riesgo de alucinación → retener.
/// - `missingFacts` + reply PREGUNTA: pide el dato que falta al cliente →
///   envío honesto (riesgo medio).
/// - `intent` vacío (escalón de JSON roto/recorte por maxTokens): el reply
///   pudo quedar truncado → riesgo medio, aún enviable (paridad con el
///   comportamiento actual).
/// - ownership humana: retener SIEMPRE (el bot no pisa al dueño).
/// - PERSONA-AUTONOMY-11 — identidad débil (confidence < 0.95, el umbral
///   safeToWrite de ConversationIdentity): sin evidencia estable de
///   plataforma (locusId/shortcutId) no hay envío automático — responder a
///   la conversación equivocada es el peor fallo de un agente personal.
///
/// Confianza: base 0.85 − penalización por señal. Umbral de envío: 0.6.
library;

import '../../engine/notifications/conversation_understanding.dart';
import '../domain/conversation_decision.dart';

final class ConversationDecisionEngine {
  const ConversationDecisionEngine();

  ConversationDecision decide({
    required ConversationUnderstanding understanding,
    ConversationDecisionContext context =
        const ConversationDecisionContext(),
  }) {
    final reasons = <String>[];

    // Ownership humana: el dueño manda. El draft se retiene SIEMPRE.
    if (context.humanOwnsConversation) {
      reasons.add('ownership: humano controla la conversación');
      return ConversationDecision(
        disposition: ConversationDisposition.holdForApproval,
        risk: ConversationRisk.low,
        confidence: 0.0,
        reasons: reasons,
      );
    }

    // PERSONA-AUTONOMY-11 — política de autonomía por identidad: sin
    // evidencia estable de plataforma el bot retiene. El humano puede
    // aprobar manualmente desde la pantalla Mensajes (TOOLS-10).
    if (context.identityConfidence < 0.95) {
      reasons.add(
        'identidad débil (${context.identityConfidence.toStringAsFixed(2)} '
        '< 0.95): sin evidencia estable de plataforma',
      );
      return ConversationDecision(
        disposition: ConversationDisposition.holdForApproval,
        risk: ConversationRisk.medium,
        confidence: 0.0,
        reasons: reasons,
      );
    }

    var confidence = 0.85;

    // requiresAction: el modelo detectó que hay que hacer algo que el bot
    // no debe ejecutar solo.
    if (understanding.requiresAction) {
      reasons.add('requiresAction: el modelo pide acción fuera de su alcance');
      return ConversationDecision(
        disposition: ConversationDisposition.needsHuman,
        risk: ConversationRisk.high,
        confidence: confidence - 0.5,
        reasons: reasons,
      );
    }

    if (understanding.missingFacts.isNotEmpty) {
      if (_isAsking(understanding.reply)) {
        // El reply pregunta por el dato que falta → envío honesto.
        reasons.add('missingFacts + pregunta: el reply pide el dato al cliente');
        confidence -= 0.15;
      } else {
        // Afirma sin el dato → probable alucinación.
        reasons.add('missingFacts + afirmación: riesgo de alucinación');
        return ConversationDecision(
          disposition: ConversationDisposition.holdForApproval,
          risk: ConversationRisk.medium,
          confidence: confidence - 0.4,
          reasons: reasons,
        );
      }
    }

    if (understanding.intent.isEmpty) {
      reasons.add('intent ausente: salida recortada (reply posiblemente truncado)');
      confidence -= 0.2;
    }

    final risk = confidence >= 0.75
        ? ConversationRisk.low
        : confidence >= 0.6
        ? ConversationRisk.medium
        : ConversationRisk.high;

    if (confidence < 0.6) {
      return ConversationDecision(
        disposition: ConversationDisposition.holdForApproval,
        risk: risk,
        confidence: confidence,
        reasons: reasons,
      );
    }

    return ConversationDecision(
      disposition: ConversationDisposition.autoSend,
      risk: risk,
      confidence: confidence,
      reasons: reasons,
    );
  }

  /// ¿El reply pregunta? Señal determinista para `missingFacts`: pedir el
  /// dato es honesto, afirmarlo sin él no. Cualquier '?' cuenta como
  /// pregunta (conservador: en la duda, el envío sale con riesgo medio, no
  /// se retiene un pedido de aclaración).
  static bool _isAsking(String reply) => reply.contains('?');
}
