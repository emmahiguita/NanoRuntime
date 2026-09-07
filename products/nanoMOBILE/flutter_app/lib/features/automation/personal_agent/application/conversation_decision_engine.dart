/// PERSONA-DECISION-02 — motor de decisión determinista (regla fundamental:
/// FACTS → DECISION → SEND; la decisión es código, no LLM).
///
/// Señales verificables (ninguna sale del modelo):
/// - `requiresAction` CON `missingFacts`: el modelo pide una acción fuera
///   de su alcance y justifica el dato que falta → humano. Sin
///   missingFacts la señal es incoherente (el 1.5B la marca hasta en un
///   saludo) y se degrada a riesgo medio — PERSONA-BUGFIX-02.
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

import '../../engine/messaging/conv_turn_state.dart' show isPureGreeting;
import '../../engine/messaging/conversation_key.dart' show ConversationIdentity;
import '../../engine/notifications/conversation_understanding.dart';
import '../domain/conversation_agent_role.dart' show ConversationAgentRole;
import '../domain/conversation_autonomy_mode.dart';
import '../domain/conversation_decision.dart';

final class ConversationDecisionEngine {
  const ConversationDecisionEngine();

  ConversationDecision decide({
    required ConversationUnderstanding understanding,
    ConversationDecisionContext context = const ConversationDecisionContext(),
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

    // AUTO-03 — modo de autonomía: tope global ANTES de la identidad.
    // disabled/suggestions retienen todo el turno (el draft se descarta y
    // se traza; la cola con aprobación en UI es el siguiente sprint).
    switch (context.autonomyMode) {
      case ConversationAutonomyMode.disabled:
        reasons.add('autonomía desactivada: el pipeline no responde');
        return ConversationDecision(
          disposition: ConversationDisposition.holdForApproval,
          risk: ConversationRisk.low,
          confidence: 0.0,
          reasons: reasons,
        );
      case ConversationAutonomyMode.suggestions:
        reasons.add('modo sugerencias: solo aprobación humana suelta el draft');
        return ConversationDecision(
          disposition: ConversationDisposition.holdForApproval,
          risk: ConversationRisk.low,
          confidence: 0.0,
          reasons: reasons,
        );
      case ConversationAutonomyMode.safeAuto:
      case ConversationAutonomyMode.autonomous:
        break; // la fórmula normal sigue intacta.
    }

    // PERSONA-AUTONOMY-11 — política de autonomía por identidad: sin
    // evidencia estable de plataforma el bot retiene. El humano puede
    // aprobar manualmente desde la pantalla Mensajes (TOOLS-10). El umbral
    // es la ÚNICA fuente ConversationIdentity.safeToWriteThreshold
    // (AUTO-CONSOLIDATE-01: antes duplicado inline).
    if (context.identityConfidence <
        ConversationIdentity.safeToWriteThreshold) {
      reasons.add(
        'identidad débil (${context.identityConfidence.toStringAsFixed(2)} '
        '< ${ConversationIdentity.safeToWriteThreshold}): sin evidencia '
        'estable de plataforma',
      );
      return ConversationDecision(
        disposition: ConversationDisposition.holdForApproval,
        risk: ConversationRisk.medium,
        confidence: 0.0,
        reasons: reasons,
      );
    }

    // P0-NO-CALLCENTER (2026-09-06) — el 1.5B ignora P0-SOCIAL con ctx=256
    // y DESPACHA muletillas de operador en turnos PERSONALES (evidencia en
    // vivo: "hola" → "¡Hola! ¿Cómo puedo ayudarte hoy?", "como estas" →
    // "Soy Nano, el asistente de este negocio. ¿En qué puedo ayudarte
    // hoy?"). Invariante del usuario: el lenguaje de soporte NO existe en
    // Personal. Guard determinista post-draft (la decisión es código, no
    // LLM): la frase de operador se retiene SIEMPRE para aprobación del
    // dueño; la identidad "Soy Nano" solo se permite si el mensaje NO fue
    // un saludo (regla 5 del prompt: un saludo no pregunta el nombre).
    if (context.agentRole == ConversationAgentRole.personal &&
        (_isCallCenterPhrase(understanding.reply) ||
            (isPureGreeting(context.userText) &&
                _fold(understanding.reply).contains('soy nano')))) {
      reasons.add('P0-NO-CALLCENTER: operador/identidad en turno personal');
      return ConversationDecision(
        disposition: ConversationDisposition.holdForApproval,
        risk: ConversationRisk.medium,
        confidence: 0.0,
        reasons: reasons,
      );
    }

    var confidence = 0.85;

    // requiresAction: el modelo detectó que hay que hacer algo que el bot
    // no debe ejecutar solo. PERSONA-BUGFIX-02 — la señal SOLO es
    // verificable si missingFacts la justifica: el 1.5B marca
    // requiresAction=true hasta en un saludo (missingFacts vacío), y
    // retener por una señal incoherente dejó el bot mudo en dispositivo
    // (evidencia: "Hola" → needsHuman → nada se envía). Sin dato faltante
    // la afirmación "necesito un dato externo" no se sostiene: se degrada
    // a riesgo medio y el reply sigue su evaluación normal.
    if (understanding.requiresAction && understanding.missingFacts.isNotEmpty) {
      reasons.add('requiresAction: el modelo pide acción fuera de su alcance');
      return ConversationDecision(
        disposition: ConversationDisposition.needsHuman,
        risk: ConversationRisk.high,
        confidence: confidence - 0.5,
        reasons: reasons,
      );
    }
    if (understanding.requiresAction) {
      reasons.add(
        'requiresAction sin missingFacts: señal incoherente, se degrada',
      );
      confidence -= 0.1;
    }

    if (understanding.missingFacts.isNotEmpty) {
      if (_isAsking(understanding.reply)) {
        // El reply pregunta por el dato que falta → envío honesto.
        reasons.add(
          'missingFacts + pregunta: el reply pide el dato al cliente',
        );
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
      reasons.add(
        'intent ausente: salida recortada (reply posiblemente truncado)',
      );
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

    // AUTO-03 — safeAuto: solo riesgo LOW y sin hechos faltantes. Un
    // saludo o un precio verificado salen; lo que pida datos ausentes se
    // retiene (jamás inventar en modo seguro).
    if (context.autonomyMode == ConversationAutonomyMode.safeAuto &&
        (risk != ConversationRisk.low ||
            understanding.missingFacts.isNotEmpty)) {
      reasons.add(
        'safeAuto: riesgo ${risk.name} o hechos faltantes — se retiene',
      );
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

  /// P0-NO-CALLCENTER — muletillas de operador prohibidas en PERSONAL.
  /// "¿En qué más puedo ayudarte?" / "¿Algo más?" / "¿Qué necesitas?" son
  /// el fallback genérico que el usuario exige estructuralmente imposible.
  static const List<String> _callCenterPhrases = [
    'puedo ayudarte',
    'en que te ayudo',
    'en que mas',
    'algo mas',
    'deseas algo',
    'necesitas algo',
    'ser util',
    'que necesitas',
  ];

  static bool _isCallCenterPhrase(String reply) {
    final r = _fold(reply);
    return _callCenterPhrases.any(r.contains);
  }

  /// Minúsculas sin tildes: matching determinista del texto del modelo.
  static String _fold(String s) => s
      .toLowerCase()
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u');
}
