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
      'hola', 'holas', 'buenas', 'buenos', 'hey', 'oe', 'ey',
      'saludos', 'ola', 'hol', 'oli', 'holi', 'quiubo', 'hubo',
    };
    if (tokens.any(greetingWords.contains) ||
        normalized.contains('buen dia') ||
        normalized.contains('buenos dias') ||
        normalized.contains('buenas tardes') ||
        normalized.contains('buenas noches') ||
        normalized.contains('que mas') ||
        normalized.contains('q mas') ||
        normalized.contains('que hubo') ||
        normalized.contains('q hubo')) {
      intents.add(ConversationIntent.greeting);
    }

    if (normalized.contains('como estas') ||
        normalized.contains('como te va') ||
        normalized.contains('como vas') ||
        normalized.contains('que tal') ||
        normalized.contains('como va todo') ||
        normalized.contains('como andas') ||
        normalized.contains('como te encuentras') ||
        normalized.contains('como te ha ido') ||
        normalized.contains('que cuentas') ||
        normalized.contains('que me cuentas') ||
        normalized.contains('todo bien?') ||
        normalized.contains('todo bien ?')) {
      intents.add(ConversationIntent.askWellbeing);
    }

    if (normalized.contains('todo bien') ||
        normalized.contains('muy bien') ||
        normalized.contains('super bien') ||
        normalized.contains('excelente') ||
        normalized.contains('tranqui') ||
        normalized.contains('por aca bien') ||
        normalized.contains('aqui bien') ||
        (tokens.contains('bien') &&
            !normalized.contains('como') &&
            !normalized.contains('que tal'))) {
      intents.add(ConversationIntent.userWellbeing);
    }

    if (normalized.contains('ya te dije') ||
        normalized.contains('te dije que bien') ||
        normalized.contains('te dije que estoy bien') ||
        normalized.contains('te acabo de decir')) {
      intents.add(ConversationIntent.wellbeingClarification);
    }

    if (normalized.contains('y tu') ||
        normalized.contains('y vos') ||
        normalized.contains('y usted') ||
        normalized.contains('que tal tu') ||
        normalized.contains('y ti') ||
        normalized.contains('y tu que') ||
        normalized.contains('y vos que') ||
        normalized.contains('que tal vos')) {
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

    if (tokens.any((t) => t.startsWith('jaja') || t.startsWith('jeje') || t.startsWith('jajaj'))) {
      intents.add(ConversationIntent.laughter);
    }

    const siPhrases = {
      'si', 'si claro', 'si de una', 'si hagamosle', 'si vamos',
      'si creo que si', 'si esta bien', 'si porfa', 'si gracias',
      'si quiero ir', 'si puede ser',
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

    final isNegation = tokens.contains('no') ||
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
        !normalized.contains('no te preocupes') &&
        !normalized.contains('no hay problema') &&
        !normalized.contains('no pasa nada')) {
      intents.add(ConversationIntent.negation);
    }
  }
}
