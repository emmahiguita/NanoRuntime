part of 'pragmatic_fast_path.dart';

/// Extracción de intenciones comunicativas básicas para PragmaticFastPath.
///
/// **QUÉ HACE:**
/// Analiza patrones lingüísticos elementales (saludos, despedidas, reciprocidad,
/// gratitud, afirmaciones, negaciones y risas).
///
/// **CÓMO FUNCIONA:**
/// Examina el texto normalizado y el set de tokens aplicando diccionarios léxicos constantes.
///
/// **POR QUÉ:**
/// Separa las intenciones básicas de las contextuales y complejas (Single Responsibility Principle),
/// manteniendo el clasificador ágil, mantenible y por debajo de 200 líneas.
extension _PragmaticBasicIntents on PragmaticFastPath {
  void _extractBasicIntents(
    Set<ConversationIntent> intents,
    String normalized,
    Set<String> tokens,
  ) {
    const greetingWords = {
      'hola',
      'holas',
      'buenas',
      'buenos',
      'hey',
      'oe',
      'ey',
      'saludo',
      'saludos',
      'ola',
      'hol',
      'oli',
      'holi',
      'quiubo',
      'hubo',
    };
    if (tokens.any(greetingWords.contains) ||
        const [
          'buen dia', 'buenos dias', 'buenas tardes', 'buenas noches',
          'cordial saludo', 'muy buenos dias', 'que mas', 'q mas', 'que hubo', 'q hubo'
        ].any(normalized.contains)) {
      intents.add(ConversationIntent.greeting);
    }

    if (const [
      'como estas', 'como te va', 'como vas', 'que tal', 'como va todo',
      'como andas', 'como te encuentras', 'como te ha ido', 'como se encuentra',
      'como anda usted', 'q tal', 'todo bn', 'que cuentas', 'que me cuentas',
      'todo bien?', 'todo bien ?'
    ].any(normalized.contains)) {
      intents.add(ConversationIntent.askWellbeing);
    }

    if (const [
      'todo bien', 'muy bien', 'super bien', 'excelente', 'tranqui',
      'por aca bien', 'aqui bien'
    ].any(normalized.contains) ||
        (tokens.contains('bien') &&
            !normalized.contains('como') &&
            !normalized.contains('que tal'))) {
      intents.add(ConversationIntent.userWellbeing);
    }

    final isReassurance = normalized == 'me alegra' ||
        normalized == 'me alegro' ||
        normalized.contains('me alegra mucho') ||
        normalized.contains('me alegro mucho') ||
        normalized.contains('que bueno') ||
        normalized.contains('que bien') ||
        normalized.startsWith('me alegra') ||
        normalized.startsWith('me alegro') ||
        // QUÉ HACE: Captura mensajes de calma/apoyo emocional ("Calma mi amor",
        //   "Tranquila amor", "No te pongas así", "Ya ya", "Ay amor").
        // POR QUÉ: Sin esto el classifier devolvía intents=[] → FastPath fallaba
        //   → iba al LLM → timeout → texto repetido >2000 chars.
        normalized.startsWith('calma') ||
        normalized.startsWith('calmate') ||
        normalized.startsWith('tranquil') ||
        normalized.startsWith('no te pongas') ||
        normalized.startsWith('no te preocupes') ||
        normalized == 'ya ya' ||
        normalized == 'eso eso' ||
        normalized.startsWith('ay amor') ||
        normalized.startsWith('ay parce') ||
        (normalized.startsWith('amor') && (
          normalized.contains('calma') ||
          normalized.contains('tranquil') ||
          normalized.contains('preocupes')
        ));
    if (isReassurance) {
      intents.add(ConversationIntent.socialReassurance);
    }

    if (const [
      'ya te dije', 'te dije que bien', 'te dije que estoy bien', 'te acabo de decir'
    ].any(normalized.contains)) {
      intents.add(ConversationIntent.wellbeingClarification);
    }

    if (const [
      'y tu', 'y vos', 'y usted', 'que tal tu', 'y ti', 'y tu que', 'y vos que', 'que tal vos'
    ].any(normalized.contains)) {
      intents.add(ConversationIntent.reciprocalQuestion);
    }

    if (normalized.contains('tarea') ||
        normalized.contains('ayuda') ||
        normalized.contains('ayudas') ||
        normalized.contains('colaboras') ||
        normalized.contains('colaborar') ||
        normalized.contains('pregunta') ||
        normalized.contains('duda') ||
        normalized.contains('un favor') ||
        normalized.contains('me ayudas') ||
        normalized.contains('me colaboras') ||
        normalized.contains('te puedo preguntar') ||
        normalized.contains('tengo una duda') ||
        normalized.contains('tengo una pregunta') ||
        normalized.contains('necesito')) {
      intents.add(ConversationIntent.askHelpOrQuestion);
    }

    if (tokens.contains('gracias') ||
        normalized.contains('muchas gracias') ||
        normalized.contains('mil gracias') ||
        normalized.contains('te agradezco') ||
        normalized.contains('muy amable')) {
      intents.add(ConversationIntent.thanks);
    }

    if (tokens.contains('chao') ||
        tokens.contains('adios') ||
        normalized.contains('hasta luego') ||
        normalized.contains('nos vemos') ||
        normalized.contains('hablamos') ||
        normalized.contains('descans') ||
        normalized.contains('hasta manana') ||
        normalized.contains('feliz noche') ||
        normalized.contains('buenas noches') ||
        normalized.contains('feliz tarde') ||
        normalized.contains('que estes bien') ||
        normalized.contains('que este bien') ||
        tokens.contains('cuidate')) {
      intents.add(ConversationIntent.farewell);
    }

    if (tokens.any(
      (t) =>
          t.startsWith('jaja') || t.startsWith('jeje') || t.startsWith('jajaj'),
    )) {
      intents.add(ConversationIntent.laughter);
    }

    const correctionPhrases = {
      'eso no lo pregunte yo', 'yo no pregunte eso', 'eso no lo pregunte',
      'no pregunte eso', 'no me refiero', 'no me referia', 'no era eso',
      'eso no fue lo que pregunte', 'te equivocaste', 'al reves',
      'eso que tiene que ver', 'de que hablas', 'a que viene eso',
    };
    if (correctionPhrases.any(normalized.contains)) {
      intents.add(ConversationIntent.userCorrection);
    }

    const siPhrases = {
      'si', 'si claro', 'si de una', 'si hagamosle', 'si vamos', 'si creo que si',
      'si esta bien', 'si porfa', 'si gracias', 'si quiero ir', 'si puede ser',
    };
    if (siPhrases.contains(normalized) ||
        tokens.contains('dale') ||
        tokens.contains('listo') ||
        tokens.contains('ok') ||
        tokens.contains('perfecto') ||
        tokens.contains('claro') ||
        tokens.contains('seguro') ||
        tokens.contains('hagamosle') ||
        normalized.contains('de una') ||
        normalized.contains('de acuerdo') ||
        normalized.contains('me parece bien') ||
        normalized.contains('me sirve') ||
        normalized.contains('listo pues') ||
        normalized.contains('dale pues')) {
      intents.add(ConversationIntent.affirmation);
    }

    final isNegation =
        tokens.contains('no') ||
        normalized.contains('para nada') ||
        normalized.contains('no gracias') ||
        normalized.contains('por ahora no') ||
        normalized.contains('no creo') ||
        normalized.contains('creo que no') ||
        normalized.contains('no puedo') ||
        normalized.contains('no se si pueda') ||
        normalized.contains('hoy no creo') ||
        normalized.contains('tal vez otro dia') ||
        normalized.contains('hoy estoy ocupado') ||
        normalized.contains('mejor despues');

    if (isNegation &&
        !intents.contains(ConversationIntent.userCorrection) &&
        !normalized.contains('no te preocupes') &&
        !normalized.contains('no hay problema') &&
        !normalized.contains('no pasa nada')) {
      intents.add(ConversationIntent.negation);
    }
  }
}
