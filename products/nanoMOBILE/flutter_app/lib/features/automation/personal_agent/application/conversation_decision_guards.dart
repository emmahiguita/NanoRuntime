// conversation_decision_guards.dart
//
// QUÉ HACE:
// Filtros léxicos, heurísticas y guardas de seguridad para decisiones conversacionales del Agente Personal.
//
// CÓMO FUNCIONA:
// - Detecta muletillas prohibidas de operador ("puedo ayudarte", "¿algo más?").
// - Normaliza cadenas eliminando tildes y signos para comparar ecos de respuestas.
// - Identifica preguntas redundantes cuando el usuario ya narró su estado o jornada.
// - Evalúa si una respuesta es una pregunta abierta o aclaración (`isAsking`).
//
// POR QUÉ:
// Separa la lógica de análisis léxico del motor de decisión principal (SOLID - SRP),
// garantizando mantenibilidad y archivos estrictamente menores a 200 líneas.

library;

import '../../engine/language/turn_complexity_classifier.dart' show turnComplexityClassifier;

abstract final class ConversationDecisionGuards {
  /// ¿El reply pregunta? Señal determinista para `missingFacts`.
  static bool isAsking(String reply) => reply.contains('?');

  /// Minúsculas sin tildes: matching determinista de texto.
  static String fold(String s) => s
      .toLowerCase()
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u');

  /// P0-NO-CALLCENTER — muletillas de operador prohibidas en turnos personales.
  static const List<String> callCenterPhrases = [
    'puedo ayudarte',
    'en que te ayudo',
    'en que mas',
    'algo mas',
    'deseas algo',
    'necesitas algo',
    'ser util',
    'que necesitas',
    'puedo hacer por',
    'hacer por ti',
    'hacer por usted',
    'puedo ayudarte en',
    'como puedo ayudarte',
    'como puedo ayudar',
    'en que puedo ayudarte',
    'en que puedo ayudar',
  ];

  static bool isCallCenterPhrase(String reply) {
    final r = fold(reply);
    return callCenterPhrases.any(r.contains);
  }

  /// Normalización para detectar eco del cliente: fold + puntuación fuera.
  static String normalizedEcho(String s) {
    var t = fold(s)
        .replaceAll('?', ' ')
        .replaceAll('¿', ' ')
        .replaceAll('!', ' ')
        .replaceAll('¡', ' ')
        .replaceAll('.', ' ')
        .replaceAll(',', ' ');
    return t.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  /// Detecta si el agente pregunta por el día cuando el usuario ya lo relató.
  static bool isRedundantStateQuestion(String? userText, String reply) {
    if (userText == null || userText.trim().isEmpty) return false;
    final u = fold(userText);
    final userToldState = u.contains('dia') ||
        u.contains('trabaj') ||
        u.contains('gym') ||
        u.contains('cansad') ||
        u.contains('en casa') ||
        turnComplexityClassifier.classify(userText).isNarrative;
    if (!userToldState) return false;

    final r = fold(reply);
    return r.contains('tal tu dia') ||
        r.contains('tal el dia') ||
        r.contains('como te fue') ||
        r.contains('como va tu dia') ||
        r.contains('como va tu jornada');
  }
}
