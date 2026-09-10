/// WA-CONV-UNDERSTANDING-01 — Clasificador determinista de complejidad del turno.
///
/// Shared entre PragmaticFastPath y NotificationDraftWriter para hacer cumplir
/// el invariante: un turno narrativo, contextual o complejo JAMÁS usa el
/// conversationSocialPromptFor (prompt mínimo). Antes la clasificación vivía
/// inline en el DraftWriter, abriendo la fuga:
///   PragmaticFastPath → NULL → DraftWriter → isSocialReactionMessage() → socialPrompt
///
/// Con este clasificador centralizado ambas rutas ven la misma lógica.
library;

/// Resultado de clasificación del turno.
final class TurnComplexity {
  /// Turno social mínimo: saludo puro / reacción social pura sin referentes.
  /// Elegible para conversationSocialPromptFor.
  final bool isSocialMinimal;

  /// El hablante relata actividades, planes, estados propios.
  final bool isNarrative;

  /// El turno contiene referencias anafóricas a algo dicho antes.
  final bool isContextual;

  /// El turno tiene múltiples cláusulas o intenciones distintas.
  final bool isComplex;

  const TurnComplexity({
    required this.isSocialMinimal,
    required this.isNarrative,
    required this.isContextual,
    required this.isComplex,
  });

  /// true si el turno puede usar el prompt social mínimo de forma segura.
  bool get eligibleForSocialPrompt =>
      isSocialMinimal && !isNarrative && !isContextual && !isComplex;
}

/// Clasificador determinista de complejidad del turno.
final class TurnComplexityClassifier {
  const TurnComplexityClassifier();

  // Patrones anafóricos: referencias a algo previo.
  static final _anaphora = RegExp(
    r'\b(eso de|sobre eso|de eso|a eso|lo de|el tema|la cosa|lo que (?:dijiste|dije|mencionaste|mencioné)|lo tuyo|lo mío|como te dije|como dijimos|como hablamos)\b',
    caseSensitive: false,
  );

  // Patrones narrativos: relato de actividades/planes propios del hablante o estados sustantivos.
  static final _narrative = RegExp(
    r'\b(fui|fuiste|fue|salí|sali|saliste|salió|salio|llegué|llegue|llegaste|llegó|llego|voy a|vas a|va a|iba a|ibas a|acabo de|acabas de|acaba de|vengo de|andaba|andabas|andaban|ya (?:fui|llegué|llegue|salí|sali|terminé|termine)|planeas|planeo|harás|haras|irás|iras|terminando|empezando|programando|programar|codigo|código|trabajando|trabajo|camellando|estudiando|universidad|proyecto|cansado|cansada|cansao|cansaod|agotado|enfermo|enferma|gimnasio|gym|entrenando|entrene|entreno|pecho|espalda|pierna|trotando|corriendo|comiendo|almorzando|cenando|cocinando|manejando|viajando|en casa|en el gym|al gym|del gym|en el trabajo|al trabajo|del trabajo|estoy muerto|muy cansado|bastante cansado|mi dia va|el mio va|ando en|ando haciendo)\b',
    caseSensitive: false,
  );

  // Reacciones sociales puras (sin referentes).
  static final _pureReaction = RegExp(
    r'^(?:ok|okay|dale|bueno|bien|listo|perfecto|genial|entendido|claro|de acuerdo|aja|jaja|jeje|gracias|muchas gracias|mil gracias)[\s.,!?]*$',
    caseSensitive: false,
  );

  // Saludos puros (con nombre opcional).
  static final _pureGreeting = RegExp(
    r'^(?:hola|hey|hi|buenos días|buenas tardes|buenas noches|buenas|qué más|que más|qué hay|que hay|holi|holaa|hola hola)(?:\s+[\wáéíóúÁÉÍÓÚñÑ]+)?[\s.,!?]*$',
    caseSensitive: false,
  );

  // Pregunta simple de bienestar (social, no narrativo).
  static final _simpleStateConcern = RegExp(
    r'^(?:cómo estás|como estás|cómo estas|como estas|bien\?|todo bien\?|todo bien$|qué tal|que tal)[\s.,!?]*$',
    caseSensitive: false,
  );

  // Múltiples cláusulas.
  static final _multiClause = RegExp(
    r'\b(y también|y además|pero también|pero además|aunque|porque|sin embargo|entonces|por eso|así que)\b',
    caseSensitive: false,
  );

  /// Clasifica el [text] para el turno.
  TurnComplexity classify(String text) {
    final t = text.trim();
    if (t.isEmpty) {
      return const TurnComplexity(
        isSocialMinimal: true,
        isNarrative: false,
        isContextual: false,
        isComplex: false,
      );
    }

    final narrativeDetected = _narrative.hasMatch(t);
    final contextualDetected = _anaphora.hasMatch(t);
    final complexDetected = _multiClause.hasMatch(t);

    final socialMinimal =
        !narrativeDetected &&
        !contextualDetected &&
        !complexDetected &&
        (_pureGreeting.hasMatch(t) ||
            _pureReaction.hasMatch(t) ||
            _simpleStateConcern.hasMatch(t));

    return TurnComplexity(
      isSocialMinimal: socialMinimal,
      isNarrative: narrativeDetected,
      isContextual: contextualDetected,
      isComplex: complexDetected,
    );
  }
}

/// Instancia global compartida (singleton stateless: sin estado mutable).
const turnComplexityClassifier = TurnComplexityClassifier();
