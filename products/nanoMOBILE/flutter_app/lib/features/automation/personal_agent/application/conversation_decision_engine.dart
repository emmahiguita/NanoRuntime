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

import '../../engine/business/fact_selector.dart' show tokenizeText;
import '../../engine/language/safe_conversation_repair.dart'
    show RepairCase, safeConversationRepair;
import '../../engine/language/turn_complexity_classifier.dart'
    show turnComplexityClassifier;
import '../../engine/messaging/conversation_key.dart' show ConversationIdentity;
import '../../engine/notifications/conversation_understanding.dart';
import '../domain/conversation_agent_role.dart'
    show
        ConversationAgentRole,
        isGreetingLikeMessage,
        isLiveStateQuestion,
        isLooseLaughterMessage,
        isSocialReactionMessage;
import '../domain/conversation_autonomy_mode.dart';
import '../domain/conversation_decision.dart';

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

    // AUTO-03 — modo de autonomía: disabled retiene de inmediato.
    // suggestions continúa por el pipeline de calidad para evaluar guards y reparar,
    // pero retiene al final para aprobación humana sin enviar automáticamente.
    if (context.autonomyMode == ConversationAutonomyMode.disabled) {
      reasons.add('autonomía desactivada: el pipeline no responde');
      return ConversationDecision(
        disposition: ConversationDisposition.holdForApproval,
        risk: ConversationRisk.low,
        confidence: 0.0,
        reasons: reasons,
      );
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
    // H7-GUARD — GENERAL también retiene muletillas de operador: el rol
    // general atiende desconocidos, pero el agente sigue siendo la persona
    // del dueño, jamás un call-center (evidencia: "ESTA TU PAPA" cayó a
    // GENERAL y recibió fallback genérico). SALES/SUPPORT quedan fuera:
    // ahí el lenguaje de servicio es legítimo.
    final callCenterTurn =
        context.agentRole == ConversationAgentRole.personal ||
        context.agentRole == ConversationAgentRole.general;
    if (callCenterTurn &&
        (_isCallCenterPhrase(understanding.reply) ||
            (isGreetingLikeMessage(context.userText) &&
                _fold(understanding.reply).contains('soy nano')))) {
      final repaired = safeConversationRepair.repair(
        RepairCase.callCenterPhrase,
        reply: understanding.reply,
        userText: context.userText,
        senderName: context.senderName,
      );
      if (allowRepair &&
          repaired != null &&
          repaired.trim() != understanding.reply.trim()) {
        return _validateRepair(
          understanding: understanding,
          context: context,
          repaired: repaired,
          reason: 'calidad reparada: muletilla call-center eliminada',
        );
      }
      reasons.add(
        'P0-NO-CALLCENTER: operador/identidad en turno personal/general',
      );
      return ConversationDecision(
        disposition: ConversationDisposition.holdForApproval,
        risk: ConversationRisk.medium,
        confidence: 0.0,
        reasons: reasons,
      );
    }

    // R6-FORMAT-LEAK-01 (2026-09-07) — prefijo de diálogo interno fugado al
    // reply: el 1.5B copia el formato de la memoria factual ("Nano: <texto>")
    // o los rótulos del protocolo como contenido de la respuesta (evidencia
    // 18:19:37: "como essta" → reply "Nano: Hola Emm." despachado literal al
    // cliente). Todo reply que arranque con un rótulo interno es formato,
    // no conversación → hold. El "Respuesta:" legacy ya lo limpia el parser;
    // aquí muere el resto de los prefijos.
    if (RegExp(
      r'^(nano|respuesta|intent|relation|questions|missingfacts|requiresaction)\s*[:=]',
    ).hasMatch(_fold(understanding.reply.trim()))) {
      reasons.add('formato interno fugado al reply (prefijo de diálogo)');
      return ConversationDecision(
        disposition: ConversationDisposition.holdForApproval,
        risk: ConversationRisk.medium,
        confidence: 0.4,
        reasons: reasons,
      );
    }

    // R6-WRONGTURN-01 (2026-09-07) — saludo fuera de turno: el reply abre
    // con pregunta-saludo cuando el mensaje del cliente NO fue un saludo.
    // Evidencia 18:23:41: "como es siempre?" → "Hola Emm, todo bien?"
    // despachado en modo autonomous (wrong-turn + confusión de
    // interlocutor: el modelo saluda al dueño en vez de responder al
    // cliente). Un humano puede saludar a mitad de charla, pero el patrón
    // de fallo del 1.5B es exactamente este: pregunta-saludo sin saludo
    // previo = turno equivocado → hold.
    final replyFold = _fold(understanding.reply.trim());
    if (replyFold.startsWith('hola') &&
        replyFold.contains('?') &&
        !isGreetingLikeMessage(context.userText)) {
      reasons.add('saludo fuera de turno (pregunta-saludo sin saludo previo)');
      return ConversationDecision(
        disposition: ConversationDisposition.holdForApproval,
        risk: ConversationRisk.medium,
        confidence: 0.35,
        reasons: reasons,
      );
    }

    // PROD-ECO-01 — reply que repite el mensaje del cliente: eco del modelo
    // con contexto degradado (evidencia física 14:19:38: "BIEN Y TU COMO
    // ESTAS?" → reply "Bien y tú, como estas?" despachado al cliente).
    // Repetir al cliente es calidad cero: se retiene para el dueño. La
    // comparación es por IGUALDAD normalizada (fold + puntuación fuera):
    // un saludo legítimo ("hola" → "Hola, ¿cómo estás?") jamás matchea.
    if (_normalizedEcho(understanding.reply).isNotEmpty &&
        _normalizedEcho(understanding.reply) ==
            _normalizedEcho(context.userText)) {
      reasons.add('reply eco del cliente: el modelo repitió el mensaje');
      return ConversationDecision(
        disposition: ConversationDisposition.holdForApproval,
        risk: ConversationRisk.medium,
        confidence: 0.5,
        reasons: reasons,
      );
    }

    // REDUNDANT-QUESTION — el reply le pregunta al cliente por su día/estado
    // cuando el cliente ya relató su actividad o día.
    if (_isRedundantStateQuestion(context.userText, understanding.reply)) {
      final repaired = safeConversationRepair.repair(
        RepairCase.redundantQuestion,
        reply: understanding.reply,
        userText: context.userText,
        senderName: context.senderName,
      );
      if (allowRepair &&
          repaired != null &&
          repaired.trim() != understanding.reply.trim()) {
        return _validateRepair(
          understanding: understanding,
          context: context,
          repaired: repaired,
          reason: 'calidad reparada: pregunta redundante de estado eliminada',
        );
      }
      reasons.add(
        'pregunta redundante sobre el estado/día ya relatado por el interlocutor',
      );
      return ConversationDecision(
        disposition: ConversationDisposition.holdForApproval,
        risk: ConversationRisk.medium,
        confidence: 0.4,
        reasons: reasons,
      );
    }

    var confidence = 0.85;

    // A11 NAME-OVERUSE — nombre del contacto repetido sin función real
    // ("Hola Diego... Bien Diego..."). El nombre solo se usa con función
    // (llamar atención, énfasis); dos menciones en un reply corto son
    // decoración artificial. Degrada, no retiene (no es daño irreversible).
    if (context.senderName.trim().isNotEmpty) {
      final name = _fold(context.senderName.trim());
      if (name.length >= 3) {
        final mentions = RegExp(
          '\\b${RegExp.escape(name)}\\b',
        ).allMatches(_fold(understanding.reply)).length;
        if (mentions >= 2) {
          reasons.add('nombre del contacto repetido sin función ($mentions×)');
          confidence -= 0.15;
        }
      }
    }

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

    // R5-05 LIVE STATE FACT — el mensaje pregunta por la actividad/estado
    // presente del dueño (isLiveStateQuestion, R5-04) y el sistema NO tiene
    // fuente viva de ese estado. Regla 6 del prompt exige honestidad: "no
    // sé" + pregunta. Todo lo demás es invento o espejo (QUESTION MIRROR
    // 4/4 en vivo: el modelo devolvió la misma pregunta o inventó
    // actividad). Gate determinista:
    // - declara ignorancia ("no sé") → pasa con degradación leve;
    // - responde con OTRA pregunta sin declarar ignorancia → espejo
    //   probable (el cliente preguntó y le devuelven su pregunta) → hold;
    // - afirma actividad/ubicación del dueño → invención → hold;
    // - respuesta social sin afirmación ("Hola, bien.") → pasa degradada.
    if (isLiveStateQuestion(context.userText)) {
      final r = _fold(understanding.reply);
      final admitsUnknown =
          r.contains('no se') ||
          r.contains('no lo se') ||
          r.contains('no estoy seguro') ||
          r.contains('no estoy segura');
      if (!admitsUnknown) {
        if (_isAsking(understanding.reply)) {
          final repaired = safeConversationRepair.repair(
            RepairCase.liveStateQuestionMirror,
            reply: understanding.reply,
            userText: context.userText,
            senderName: context.senderName,
          );
          if (allowRepair &&
              repaired != null &&
              repaired.trim() != understanding.reply.trim()) {
            return _validateRepair(
              understanding: understanding,
              context: context,
              repaired: repaired,
              reason:
                  'calidad reparada: LIVE STATE question mirror corregido a respuesta honesta',
            );
          }
          reasons.add(
            'LIVE STATE: reply espeja la pregunta sobre el dueño '
            '(QUESTION MIRROR)',
          );
          return ConversationDecision(
            disposition: ConversationDisposition.holdForApproval,
            risk: ConversationRisk.medium,
            confidence: confidence - 0.3,
            reasons: reasons,
          );
        }
        if (_affirmsOwnerActivity(understanding.reply)) {
          final repaired = safeConversationRepair.repair(
            RepairCase.liveStateAffirmed,
            reply: understanding.reply,
            userText: context.userText,
            senderName: context.senderName,
          );
          if (allowRepair &&
              repaired != null &&
              repaired.trim() != understanding.reply.trim()) {
            return _validateRepair(
              understanding: understanding,
              context: context,
              repaired: repaired,
              reason:
                  'calidad reparada: LIVE STATE actividad afirmada corregida a respuesta honesta',
            );
          }
          reasons.add(
            'LIVE STATE: reply afirma actividad/estado del dueño sin '
            'fuente viva',
          );
          return ConversationDecision(
            disposition: ConversationDisposition.holdForApproval,
            risk: ConversationRisk.medium,
            confidence: confidence - 0.35,
            reasons: reasons,
          );
        }
      }
      reasons.add('LIVE STATE: reply honesto o social, degradación leve');
      confidence -= 0.1;
    }

    // R5-05 COVERAGE — el mensaje trae VARIAS preguntas y el 1.5B suele
    // responder solo la última. Sin NLU la cobertura pregunta a pregunta
    // no es verificable: degradación honesta, no hold (el reply puede
    // responder ambas sin signos de interrogación).
    if (understanding.questions.length >= 2) {
      reasons.add('multi-pregunta: cobertura no verificable sin NLU, degrada');
      confidence -= 0.1;
    }

    // PROD-SALUDO-01 — saludo puro con reply corto: el 1.5B no emite el
    // JSON estructurado en saludos (evidencia física 3/3: "Hola" → reply
    // "Emm, hola!" con intent="") y la penalización de recorte retenía el
    // saludo SIEMPRE en safeAuto (conf 0.65 = medium), contradiciendo la
    // promesa del modo ("saludos salen"). Un saludo social corto no tiene
    // intent comercial que perder ni recorte dañino posible: se traza sin
    // degradar. Saludo NO puro ("hola, ¿está Emmanuel?") conserva la
    // penalización completa.
    // PROD-SOCIAL-03 — mismo fenómeno en reacciones sociales ("bien y tu,
    // como estas?" → reply eco "¿Cómo estás?" con intent=""): el turno
    // social continuo tampoco tiene estructura comercial que perder.
    if (understanding.intent.isEmpty) {
      if (isGreetingLikeMessage(context.userText) ||
          isSocialReactionMessage(context.userText) ||
          isLooseLaughterMessage(context.userText)) {
        reasons.add(
          'intent ausente en turno social corto: reply social, no degrada',
        );
      } else {
        reasons.add(
          'intent ausente: salida recortada (reply posiblemente truncado)',
        );
        confidence -= 0.2;
      }
    }

    // CONV-SEM-02 / CONV-AGENT-01 — relación semántica del mensaje con la
    // conversación previa (declarada por la MISMA inferencia que escribió
    // el reply; jamás una segunda pasada LLM). corrige/rechaza con reply
    // ASERTIVO se retiene: el cliente acaba de deshacer o rechazar el turno
    // anterior y afirmar sobre ese contexto muerto es alucinación probable
    // (invariante UNKNOWN OUTCOME != SUCCESS). Con reply PREGUNTA degrada
    // la confianza y sigue: pedir el dato correcto es la reparación
    // honesta. La relación jamás eleva ni decide el envío por sí sola.
    if (understanding.relation == 'corrige' ||
        understanding.relation == 'rechaza') {
      if (_isAsking(understanding.reply)) {
        reasons.add(
          'relation=${understanding.relation} + pregunta: reparación '
          'honesta, riesgo medio',
        );
        confidence -= 0.15;
      } else {
        reasons.add(
          'relation=${understanding.relation} + afirmación: contexto '
          'deshecho por el cliente, se retiene',
        );
        return ConversationDecision(
          disposition: ConversationDisposition.holdForApproval,
          risk: ConversationRisk.medium,
          confidence: confidence - 0.15,
          reasons: reasons,
        );
      }
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

    // AUTO-03 — suggestions mode retiene el draft con su confianza y calidad calculadas.
    if (context.autonomyMode == ConversationAutonomyMode.suggestions) {
      reasons.add('modo sugerencias: draft retenido para aprobación');
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

  /// Repair changes only the proposed text, never the facts or authority.
  /// Run every guard again because stripping/replacing text can change whether
  /// it is an assertion, an echo, or a question. One repair attempt per decision
  /// keeps the validation bounded, including when a repair leaves a defect.
  ConversationDecision _validateRepair({
    required ConversationUnderstanding understanding,
    required ConversationDecisionContext context,
    required String repaired,
    required String reason,
  }) {
    final candidate = ConversationUnderstanding(
      intent: understanding.intent,
      relation: understanding.relation,
      questions: understanding.questions,
      missingFacts: understanding.missingFacts,
      requiresAction: understanding.requiresAction,
      reply: repaired.trim(),
    );
    final validated = _decide(
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

  /// ¿El reply pregunta? Señal determinista para `missingFacts`: pedir el
  /// dato es honesto, afirmarlo sin él no. Cualquier '?' cuenta como
  /// pregunta (conservador: en la duda, el envío sale con riesgo medio, no
  /// se retiene un pedido de aclaración).
  static bool _isAsking(String reply) => reply.contains('?');

  /// R5-05 LIVE STATE FACT — ¿el reply afirma actividad o ubicación del
  /// dueño en presente/futuro? Heurística determinista sobre verbos y
  /// marcas de estado en primera persona. Sin fuente viva del estado del
  /// dueño, cualquiera de estas marcas en un turno de pregunta de estado
  /// es invención ("estoy trabajando", "estoy por ahí", "hoy voy a
  /// grabar"). Respuestas sin estas marcas ("Hola, bien.") no afirman
  /// actividad y pasan degradadas.
  static bool _affirmsOwnerActivity(String reply) {
    final r = _fold(reply);
    final tokens = tokenizeText(r);
    const wordMarks = {
      'estoy',
      'estaba',
      'ando',
      'hago',
      'haciendo',
      'trabajando',
      'ocupado',
      'ocupada',
      'durmiendo',
      'descansando',
      'llegando',
      'grabando',
      'cantando',
      'jugando',
    };
    if (tokens.any(wordMarks.contains)) return true;

    const phraseMarks = [
      'voy a',
      'voy pa',
      'en casa',
      'en el trabajo',
      'en la calle',
      'por ahi',
      'por ahí',
      'acabo de',
    ];
    return phraseMarks.any(r.contains);
  }

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
    // R6-CALLCENTER-01 (2026-09-07) — variantes de ofrecimiento que
    // escaparon la lista y se despacharon en vivo (evidencia 18:19:03:
    // "Hola, ¿qué puedo hacer por usted hoy?" REMOTE_INPUT_ACCEPTED ante
    // una risa suelta "Jajajsjsjsja"). "puedo hacer por" cubre ti/usted;
    // "puedo ayudarte en" cubre la forma extendida con contexto.
    'puedo hacer por',
    'hacer por ti',
    'hacer por usted',
    'puedo ayudarte en',
    'como puedo ayudarte',
    'como puedo ayudar',
    'en que puedo ayudarte',
    'en que puedo ayudar',
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

  /// PROD-ECO-01 — normalización para detectar eco: fold + puntuación final
  /// y espacios sobrantes fuera. "Bien y tú, como estas?" y "BIEN Y TU COMO
  /// ESTAS?" colapsan al mismo texto; un reply que AÑADE contenido ("Hola,
  /// ¿cómo estás?" ante "hola") jamás matchea por igualdad.
  static String _normalizedEcho(String s) {
    var t = _fold(s)
        .replaceAll('?', ' ')
        .replaceAll('!', ' ')
        .replaceAll('.', ' ')
        .replaceAll(',', ' ');
    return t.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  static bool _isRedundantStateQuestion(String? userText, String reply) {
    if (userText == null || userText.trim().isEmpty) return false;
    final u = _fold(userText);
    final userToldState = u.contains('dia') ||
        u.contains('trabaj') ||
        u.contains('gym') ||
        u.contains('cansad') ||
        u.contains('en casa') ||
        turnComplexityClassifier.classify(userText).isNarrative;
    if (!userToldState) return false;

    final r = _fold(reply);
    final asksAboutDay = r.contains('tal tu dia') ||
        r.contains('tal el dia') ||
        r.contains('como te fue') ||
        r.contains('como va tu dia') ||
        r.contains('como va tu jornada');
    return asksAboutDay;
  }
}
