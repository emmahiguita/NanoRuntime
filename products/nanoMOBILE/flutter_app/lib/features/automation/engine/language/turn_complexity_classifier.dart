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

import 'dialogue_state.dart' show linguisticAnalyzer;

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
  // Nota: 'vas a' se excluye porque corresponde a preguntas al interlocutor (2da persona), no relato del hablante.
  static final _narrative = RegExp(
    r'\b(fui|fuiste|fue|salí|sali|saliste|salió|salio|llegué|llegue|llegaste|llegó|llego|voy a|va a|iba a|ibas a|acabo de|acabas de|acaba de|vengo de|andaba|andabas|andaban|ya (?:fui|llegué|llegue|salí|sali|terminé|termine)|planeo|terminando|empezando|programando|programar|codigo|código|trabajando|trabajo|camellando|estudiando|universidad|proyecto|cansado|cansada|cansao|cansaod|agotado|enfermo|enferma|gimnasio|gym|entrenando|entrene|entreno|pecho|espalda|pierna|trotando|corriendo|comiendo|almorzando|cenando|cocinando|manejando|viajando|en casa|en el gym|al gym|del gym|en el trabajo|al trabajo|del trabajo|estoy muerto|muy cansado|bastante cansado|mi dia va|el mio va|ando en|ando haciendo)\b',
    caseSensitive: false,
  );

  // Reacciones sociales puras (sin referentes).
  static final _pureReaction = RegExp(
    r'^(?:ok|okay|dale|bueno|bien|listo|perfecto|genial|entendido|claro|de acuerdo|aja|jaja|jeje|gracias|muchas gracias|mil gracias)[\s.,!?]*$',
    caseSensitive: false,
  );

  // Despedidas puras (sin referentes).
  static final _pureFarewell = RegExp(
    r'^(?:chao|adiós|adios|hasta luego|hasta mañana|hasta manana|nos vemos|hablamos|que descanses|descansa|feliz noche|buenas noches|cuídate|cuidate)[\s.,!?]*$',
    caseSensitive: false,
  );

  // Saludos puros (con nombre opcional y tolerancia a typos comunes como hol, ola).
  static final _pureGreeting = RegExp(
    r'^(?:hola|hol|ola|oli|hey|hi|buenos días|buenas tardes|buenas noches|buenas|qué más|que más|qué hay|que hay|holi|holaa|hola hola)(?:\s+[\wáéíóúÁÉÍÓÚñÑ]+)?[\s.,!?]*$',
    caseSensitive: false,
  );

  // Pregunta simple de bienestar (social, no narrativo).
  static final _simpleStateConcern = RegExp(
    r'^(?:cómo estás|como estás|cómo estas|como estas|bien\?|todo bien\?|todo bien$|qué tal|que tal)[\s.,!?]*$',
    caseSensitive: false,
  );

  // Saludo social compuesto con pregunta de bienestar ("hola cómo estás", "hola, ¿todo bien?", "buenas, qué tal").
  static final _socialGreetingWellbeing = RegExp(
    r'^(?:hola|hol|ola|hey|hi|buenas|buenos días|buenas tardes|buenas noches|qué más|que más|holi|holaa|hola hola)?[\s,¡!¿?]*'
    r'(?:cómo estás|como estás|cómo estas|como estas|cómo vas|como vas|cómo te va|como te va|qué tal|que tal|todo bien\??|cómo andas|como andas|qué hay|que hay)'
    r'(?:\s+[\wáéíóúÁÉÍÓÚñÑ]+)?[\s.,!?]*$',
    caseSensitive: false,
  );

  // Pregunta recíproca / bienestar de vuelta ("bien y tu ?", "bien tk y tu!?", "estoy bien y tu", "y tu?").
  static final _reciprocalWellbeing = RegExp(
    r'^(?:estoy\s+)?(?:bien|todo bien|muy bien|super bien|excelente|tranqui|por acá bien|por aca bien|aqui bien|aquí bien)?'
    r'[\s,]*(?:tk\s+)?(?:y\s+(?:tú|tu|vos|usted|ti)|qué tal tú|que tal tu|qué tal vos|que tal vos)'
    r'(?:[\s,]+(?:cómo estás|como estás|cómo estas|como estas|cómo vas|como vas))?'
    r'[\s.,!?]*$',
    caseSensitive: false,
  );

  // Preguntas de actividad cotidiana / planes / día (sociales, no narrativas del usuario).
  static final _socialActivityInquiry = RegExp(
    r'^(?:(?:hola|hol|ola|buenas|hey|oe|holi)\s*,?\s*)?'
    r'(?:(?:me\s+alegra\s+(?:que\s+est[eé]s\s+bien|mucho)\s*,?\s*|qu[eé]\s+bueno\s*,?\s*)?)'
    r'(?:qu[eé]\s+(?:vas\s+(?:a\s+)?hacer|haces|haciendo|est[aá]s\s+haciendo|har[aá]s|har[eé]s|planes\s+tienes|tienes\s+pensado(?:\s+hacer)?|cuentas|hay\s+de\s+nuevo)|vas\s+(?:a\s+)?(?:salir|entrenar)|en\s+qu[eé]\s+andas|c[oó]mo\s+va\s+tu\s+d[ií]a|qu[eé]\s+tal\s+tu\s+d[ií]a|c[oó]mo\s+va\s+el\s+d[ií]a|est[aá]s\s+ah[ií]|sigues\s+ah[ií])'
    r'(?:\s+(?:hoy|ahora|m[aá]s\s+tarde|parce|bro|amigo|emma))?[\s.,!?]*$',
    caseSensitive: false,
  );

  // Reacciones sociales de bienestar hacia el otro ("me alegra que estés bien", "qué bueno que estés bien", "me alegra").
  static final _socialWellbeingReassurance = RegExp(
    r'^(?:me\s+alegra(?:\s+(?:mucho|que\s+est[eé]s\s+bien))?|me\s+alegro|qu[eé]\s+bueno(?:\s+que\s+est[eé]s\s+bien)?|qu[eé]\s+bien)[\s.,!?]*$',
    caseSensitive: false,
  );

  // Invitaciones sociales cotidianas ("vamos a rapear", "vamos?", "¿quieres ir?", "sale o que").
  static final _socialInvitation = RegExp(
    r'^(?:(?:hola|hol|buenas|hey|oe|ey)\s*,?\s*)?'
    r'(?:vamos(?:\s+a\s+(?:rapear|salir|improvisar))?|¿?vamos\??|quieres\s+ir(?:\s+a\s+rapear)?|sale\s+o\s+qu[eé]|te\s+apuntas(?:\s+a\s+rapear)?|le\s+caes|caes\s+hoy)'
    r'(?:\s+(?:hoy|ahora|m[aá]s\s+tarde|un\s+rato|parce|bro|emma))?[\s.,!?]*$',
    caseSensitive: false,
  );

  // Aclaración o reaseguro social de bienestar ("ya te dije que estoy bien", "te dije que bien", "ya te dije").
  static final _socialWellbeingClarification = RegExp(
    r'^(?:ya\s+)?(?:te\s+dije|te\s+acabo\s+de\s+decir|te\s+hab[íi]a\s+dicho)(?:\s+que)?(?:\s+(?:estoy\s+)?(?:bien|todo\s+bien|muy\s+bien|tranqui))?[\s.,!?]*$',
    caseSensitive: false,
  );

  // Negaciones y rechazos sociales breves ("no", "no creo", "creo que no", "hoy no creo", "por ahora no").
  static final _socialRefusal = RegExp(
    r'^(?:no|no\s+creo|creo\s+que\s+no|no\s*,\s*hoy\s+no|hoy\s+no\s+creo|por\s+ahora\s+no|no\s+gracias|no\s+puedo\s+hoy|tal\s+vez\s+otro\s+d[ií]a|hoy\s+estoy\s+ocupado|mejor\s+despu[eé]s)[\s.,!?]*$',
    caseSensitive: false,
  );

  // Consultas sociales ampliadas (disponibilidad, comida, casa, familia, noche, música, clima, llamadas, ausencia, opinión)
  static final _situationalSocialInquiry = RegExp(
    r'^(?:(?:hola|hol|ola|buenas|hey|oe|holi)\s*,?\s*)?'
    r'(?:(?:est[aá]s|andas)\s+ocupad[oa]|tienes\s+(?:tiempo|un\s+(?:momento|minuto|ratico))|puedes\s+hablar|est[aá]s\s+libre|'
    r'almorzaste|ya\s+comiste|cenaste|desayunaste|vas\s+a\s+comer|tienes\s+hambre|qu[eé]\s+(?:almorzaste|comiste|cenaste)|'
    r'(?:est[aá]s|andas)\s+en\s+(?:la\s+)?casa|'
    r'(?:c[oó]mo\s+est[aá]|qu[eé]\s+tal)\s+(?:tu\s+familia|la\s+familia)|c[oó]mo\s+est[aá]n\s+en\s+la\s+casa|'
    r'vas\s+a\s+dormir|te\s+vas\s+a\s+(?:dormir|acostar)|sigues\s+despierto|trasnochando|'
    r'qu[eé]\s+(?:est[aá]s\s+escuchando|m[uú]sica\s+escuchas|tema\s+est[aá]s\s+oyendo)|'
    r'(?:est[aá]\s+)?lloviendo|mucho\s+calor|hace\s+fr[ií]o|c[oó]mo\s+est[aá]\s+el\s+clima|'
    r'(?:te\s+)?puedo\s+llamar|hacemos\s+llamada|hablar\s+por\s+llamada|'
    r'te\s+perdiste|qu[eé]\s+te\s+hiciste|por\s+qu[eé]\s+tan\s+perdido|'
    r'c[oó]mo\s+lo\s+ves|qu[eé]\s+opinas|te\s+gusta|qu[eé]\s+tal\s+te\s+parece|est[aá]\s+(?:bacano|chimba))'
    r'(?:\s+(?:hoy|ahora|m[aá]s\s+tarde|parce|bro|amigo|emma|\?))?[\s.,!?]*$',
    caseSensitive: false,
  );

  // Múltiples cláusulas complejas.
  static final _multiClause = RegExp(
    r'\b(y también|y además|pero también|pero además|aunque|porque|sin embargo|por eso|así que)\b',
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

    final signals = linguisticAnalyzer.analyze(t);
    final isSocialClarification = _socialWellbeingClarification.hasMatch(t);
    final isSituationalInquiry = _situationalSocialInquiry.hasMatch(t);
    final isSocialExemption = isSocialClarification || isSituationalInquiry;
    final narrativeDetected = _narrative.hasMatch(t) || (!isSocialExemption && signals.isCorrection);
    final contextualDetected = !isSocialExemption && (_anaphora.hasMatch(t) || signals.hasReference);
    final isSocialRefusal = _socialRefusal.hasMatch(t);
    final complexDetected = !isSocialRefusal &&
        !isSocialExemption &&
        (_multiClause.hasMatch(t) ||
            signals.isMultiIntent ||
            (signals.hasNegation &&
                (signals.negationScope?.isNotEmpty ?? false)));

    final socialMinimal =
        !narrativeDetected &&
        !contextualDetected &&
        !complexDetected &&
        (_pureGreeting.hasMatch(t) ||
            _pureReaction.hasMatch(t) ||
            _pureFarewell.hasMatch(t) ||
            _simpleStateConcern.hasMatch(t) ||
            _socialGreetingWellbeing.hasMatch(t) ||
            _reciprocalWellbeing.hasMatch(t) ||
            _socialActivityInquiry.hasMatch(t) ||
            _socialWellbeingReassurance.hasMatch(t) ||
            _socialInvitation.hasMatch(t) ||
            isSocialClarification ||
            isSituationalInquiry ||
            isSocialRefusal);

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
