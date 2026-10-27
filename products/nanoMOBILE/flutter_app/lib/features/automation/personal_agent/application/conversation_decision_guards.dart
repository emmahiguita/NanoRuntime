import '../../../../core/services/conversation_reply_quality.dart';
import '../../engine/business/fact_selector.dart' show tokenizeText;
import '../../engine/language/turn_complexity_classifier.dart'
    show turnComplexityClassifier;

/// Guardas léxicas precisas para decisiones conversacionales del Agente Personal.
///
/// - **QUÉ HACE:** Evalúa si una respuesta afirma actividades físicas concretas
///   no verificadas, frases de operador (call-center) o preguntas redundantes.
/// - **CÓMO FUNCIONA:** Evita bloquear verbos cotidianos genéricos (`"estoy"`,
///   `"hago"`, `"haciendo"`, `"ahora mismo"`) y solo marca actividades físicas
///   o lugares específicos (`"almorzando"`, `"en el gimnasio"`, `"en la oficina"`).
/// - **POR QUÉ:** Así Nano nunca retiene ni bloquea respuestas conversacionales
///   normales por falsos positivos.
abstract final class ConversationDecisionGuards {
  /// ¿El reply contiene una pregunta?
  static bool isAsking(String reply) => reply.contains('?');

  /// Evalúa únicamente si la respuesta afirma una actividad física o ubicación
  /// concreta del dueño sin estar respaldada por el cronograma del día.
  static bool affirmsOwnerActivity(String reply) {
    final r = fold(reply)
        // Quita preguntas también sin «¿», sin borrar afirmaciones anteriores.
        .replaceAll(RegExp(r'(?:¿|^|(?<=[.!]))[^?.!]*\?'), '')
        .replaceAll(RegExp(r'\bno\s+(?:lo\s+)?se\b'), '')
        .replaceAll(RegExp(r'\bno\s+estoy\s+segur[oa]\b'), '');
    final tokens = tokenizeText(r);
    if (tokens.isEmpty) return false;
    const concreteActivityWords = {
      'trabajando',
      'programando',
      'entrenando',
      'estudiando',
      'almorzando',
      'comiendo',
      'cenando',
      'desayunando',
      'durmiendo',
      'manejando',
      'conduciendo',
    };
    if (tokens.any(concreteActivityWords.contains)) return true;

    const concreteLocationPhrases = [
      'voy camino',
      'en el trabajo',
      'en la oficina',
      'en el gym',
      'en el gimnasio',
      'en la calle',
      'para el centro',
      'pa el centro',
      'ya comi',
      'ya almorce',
      'no he comido',
    ];
    return concreteLocationPhrases.any(r.contains);
  }

  /// Minúsculas sin tildes para comparaciones deterministas.
  static String fold(String s) => s
      .toLowerCase()
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u');

  /// Muletillas de operador prohibidas en turnos personales.
  static const List<String> callCenterPhrases = [
    'puedo ayudarte',
    'en que te ayudo',
    'en que mas',
    'deseas algo',
    'ser util',
    'puedo hacer por',
    'hacer por ti',
    'hacer por usted',
    'puedo ayudarte en',
    'como puedo ayudarte',
    'como puedo ayudar',
    'en que puedo ayudarte',
    'en que puedo ayudar',
    'a su disposicion',
    'a tu disposicion',
  ];

  static bool isCallCenterPhrase(String reply) {
    final r = fold(reply);
    return callCenterPhrases.any(r.contains);
  }

  static String normalizedEcho(String s) => ConversationReplyQuality.lexical(s);

  /// Detecta si el modelo repite como pregunta algo que el usuario ya afirmó.
  static bool isRedundantStateQuestion(String? userText, String reply) {
    if (userText == null || userText.trim().isEmpty) return false;
    final u = fold(userText);
    final r = fold(reply);

    final preferenceMatch = RegExp(
      r'\b(?:me gusta(?:n)?|me encanta(?:n)?|soy fan de|soy hincha de|prefiero)\s+(?:el\s+|la\s+|los\s+|las\s+)?([a-z0-9]{3,})',
    ).firstMatch(u);
    if (preferenceMatch != null) {
      final topic = preferenceMatch.group(1)!;
      if (r.contains(topic) &&
          (r.contains('eres fan') ||
              r.contains('te gusta') ||
              r.contains('asi que te gusta') ||
              r.contains('entonces te gusta'))) {
        return true;
      }
    }

    final userToldState =
        u.contains('dia') ||
        u.contains('trabaj') ||
        u.contains('gym') ||
        u.contains('cansad') ||
        u.contains('en casa') ||
        turnComplexityClassifier.classify(userText).isNarrative;
    if (!userToldState) return false;

    return r.contains('tal tu dia') ||
        r.contains('tal el dia') ||
        r.contains('como te fue') ||
        r.contains('como va tu dia') ||
        r.contains('como va tu jornada');
  }
}
