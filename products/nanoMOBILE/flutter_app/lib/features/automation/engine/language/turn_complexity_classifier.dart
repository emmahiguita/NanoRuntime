/// WA-CONV-UNDERSTANDING-01 — Clasificador determinista de complejidad del turno.
///
/// Shared entre PragmaticFastPath y NotificationDraftWriter para hacer cumplir
/// el invariante: un turno narrativo, contextual o complejo JAMÁS usa el
/// conversationSocialPromptFor (prompt mínimo).
/// Cumple Clean Architecture y límite estricto < 200 líneas.
library;

import 'dialogue_state.dart' show linguisticAnalyzer;
import 'turn_complexity.dart';

export 'turn_complexity.dart';

/// Clasificador determinista de complejidad del turno.
final class TurnComplexityClassifier {
  const TurnComplexityClassifier();

  static final _anaphora = RegExp(
    r'\b(eso de|sobre eso|de eso|a eso|lo de|el tema|la cosa|lo que (?:dijiste|dije|mencionaste|mencioné)|lo tuyo|lo mío|como te dije|como dijimos|como hablamos)\b',
    caseSensitive: false,
  );

  static final _narrative = RegExp(
    r'\b(fui|fuiste|fue|salí|sali|saliste|salió|salio|llegué|llegue|llegaste|llegó|llego|voy a|va a|iba a|ibas a|acabo de|acabas de|acaba de|vengo de|andaba|andabas|andaban|ya (?:fui|llegué|llegue|salí|sali|terminé|termine)|planeo|terminando|empezando|programando|programar|codigo|código|trabajando|trabajo|camellando|estudiando|universidad|proyecto|cansado|cansada|cansao|cansaod|agotado|enfermo|enferma|gimnasio|gym|entrenando|entrene|entreno|pecho|espalda|pierna|trotando|corriendo|comiendo|almorzando|cenando|cocinando|manejando|viajando|en casa|en el gym|al gym|del gym|en el trabajo|al trabajo|del trabajo|estoy muerto|muy cansado|bastante cansado|mi dia va|el mio va|ando en|ando haciendo)\b',
    caseSensitive: false,
  );

  static final _pureReaction = RegExp(
    r'^(?:ok|okay|dale|bueno|bien|listo|perfecto|genial|entendido|claro|de acuerdo|aja|jaja|jeje|gracias|muchas gracias|mil gracias)[\s.,!?]*$',
    caseSensitive: false,
  );

  static final _pureFarewell = RegExp(
    r'^(?:chao|adiós|adios|hasta luego|hasta mañana|hasta manana|nos vemos|hablamos|que descanses|descansa|feliz noche|buenas noches|cuídate|cuidate)[\s.,!?]*$',
    caseSensitive: false,
  );

  static final _pureGreeting = RegExp(
    r'^(?:hola|hol|ola|oli|hey|hi|buen día|buen dia|buenos días|muy buenos días|muy buenos dias|buenas tardes|buenas noches|buenas|cordial saludo|saludos|qué más|que más|q más|q mas|qué hay|que hay|holi|holaa|hola hola)(?:\s+[\wáéíóúÁÉÍÓÚñÑ]+)?[\s.,!?]*$',
    caseSensitive: false,
  );

  static final _simpleStateConcern = RegExp(
    r'^(?:[¿¡]?(?:cómo estás|como estás|cómo estas|como estas|cómo se encuentra(?: usted)?|como se encuentra(?: usted)?|cómo anda(?: usted)?|como anda(?: usted)?|bien\?|todo bien\?|todo bien$|todo bn\?|todo bn$|qué tal|que tal|q tal)[\s.,!?]*)$',
    caseSensitive: false,
  );

  static final _socialGreetingWellbeing = RegExp(
    r'^(?:(?:hola|hol|ola|hey|hi|buen día|buen dia|buenas|buenos días|muy buenos días|muy buenos dias|buenas tardes|buenas noches|cordial saludo|saludos|qué más|que más|q más|q mas|holi|holaa|hola hola|bien|todo bien)\s*[,¡!¿?]*\s*)*'
    r'(?:[,¡!¿?]*\s*(?:cómo estás|como estás|cómo estas|como estas|cómo se encuentra|como se encuentra|cómo anda|como anda|cómo vas|como vas|cómo te va|como te va|qué tal(?: todo)?|que tal(?: todo)?|q tal(?: todo bn)?|todo bien\??|todo bn\??|cómo andas|como andas|qué hay|que hay)\s*(?:hoy|parce|bro|amigo|todo|bien)?\s*[,¡!¿?]*\s*)+$',
    caseSensitive: false,
  );

  static final _reciprocalWellbeing = RegExp(
    r'^(?:estoy\s+)?(?:bien|todo bien|muy bien|super bien|excelente|tranqui|por acá bien|por aca bien|aqui bien|aquí bien)?'
    r'[\s,]*(?:tk\s+)?(?:y\s+(?:tú|tu|vos|usted|ti)|qué tal tú|que tal tu|qué tal vos|que tal vos)'
    r'(?:[\s,]+(?:cómo estás|como estás|cómo estas|como estas|cómo vas|como vas))?'
    r'[\s.,!?]*$',
    caseSensitive: false,
  );

  static final _socialActivityInquiry = RegExp(
    r'^(?:(?:hola|hol|ola|buenas|hey|oe|holi|bien|todo bien|super|tranqui)\s*,?\s*)?'
    r'(?:y\s+)?'
    r'(?:(?:me\s+alegra\s+(?:que\s+est[eé]s\s+bien|mucho)\s*,?\s*|qu[eé]\s+bueno\s*,?\s*)?)'
    r'(?:qu[eé]\s+(?:vas\s+(?:a\s+)?hacer|haces|haciendo|est[aá]s\s+haciendo|har[aá]s|har[eé]s|planes\s+tienes|tienes\s+pensado(?:\s+hacer)?|cuentas|hay\s+de\s+nuevo)|vas\s+(?:a\s+)?(?:salir|entrenar)|en\s+qu[eé]\s+andas|c[oó]mo\s+va\s+tu\s+d[ií]a|qu[eé]\s+tal\s+tu\s+d[ií]a|c[oó]mo\s+va\s+el\s+d[ií]a|est[aá]s\s+ah[ií]|sigues\s+ah[ií])'
    r'(?:\s+(?:hoy|ahora|m[aá]s\s+tarde|parce|bro|amigo|emma))?[\s.,!?]*$',
    caseSensitive: false,
  );

  static final _socialWellbeingReassurance = RegExp(
    r'^(?:me\s+alegra(?:\s+(?:mucho|que\s+est[eé]s\s+bien))?|me\s+alegro|qu[eé]\s+bueno(?:\s+que\s+est[eé]s\s+bien)?|qu[eé]\s+bien)[\s.,!?]*$',
    caseSensitive: false,
  );

  static final _socialInvitation = RegExp(
    r'^(?:(?:hola|hol|buenas|hey|oe|ey)\s*,?\s*)?'
    r'(?:vamos(?:\s+a\s+(?:rapear|salir|improvisar))?|¿?vamos\??|quieres\s+ir(?:\s+a\s+rapear)?|sale\s+o\s+qu[eé]|te\s+apuntas(?:\s+a\s+rapear)?|le\s+caes|caes\s+hoy)'
    r'(?:\s+(?:hoy|ahora|m[aá]s\s+tarde|un\s+rato|parce|bro|emma))?[\s.,!?]*$',
    caseSensitive: false,
  );

  static final _socialWellbeingClarification = RegExp(
    r'^(?:ya\s+)?(?:te\s+dije|te\s+acabo\s+de\s+decir|te\s+hab[íi]a\s+dicho)(?:\s+que)?(?:\s+(?:estoy\s+)?(?:bien|todo\s+bien|muy\s+bien|tranqui))?[\s.,!?]*$',
    caseSensitive: false,
  );

  static final _socialRefusal = RegExp(
    r'^(?:no|no\s+creo|creo\s+que\s+no|no\s*,\s*hoy\s+no|hoy\s+no\s+creo|por\s+ahora\s+no|no\s+gracias|no\s+puedo\s+hoy|tal\s+vez\s+otro\s+d[ií]a|hoy\s+estoy\s+ocupado|mejor\s+despu[eé]s)[\s.,!?]*$',
    caseSensitive: false,
  );

  // QUÉ HACE: Captura mensajes emocionales/afectivos cortos como "Calma mi amor",
  //   "Tranquila amor", "No te pongas así", "Ya ya", "Eso eso", "Ay amor".
  // CÓMO FUNCIONA: Regex que matchea frases de ≤6 palabras con token emocional
  //   o apelativo afectivo sin contenido narrativo/contextual.
  // POR QUÉ: "Calma mi amor" tenía social=false → iba al LLM → timeout → explosión
  //   de texto. Con este regex isSocialMinimal=true → FastPath lo resuelve en <5ms.
  static final _pureEmotionalSocial = RegExp(
    r'^(?:(?:calma|calmá|tranquila?|tranquilizate|tranquilízate|no\s+te\s+pongas\s+as[ií]|no\s+te\s+preocupes?|ya\s+ya|eso\s+eso|ay\s+amor|ay\s+parce|ay\s+dios|ay\s+no|uy|wow|vaya|qué\s+cosa|de\s+verdad|en\s+serio)(?:\s+(?:amor|mi\s+amor|corazón|corazon|cielo|papi|mami|parce|hermano|hermana|bro|rey|reina|nena|nene|bebé|bebe|muñeca|cariño|carino))?|(?:amor|mi\s+amor|corazón|corazon|cielo)\s+(?:calma|tranquila?|no\s+te\s+preocupes?))[\s.,!?]*$',
    caseSensitive: false,
  );

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
    final isWellbeingMatch = _socialGreetingWellbeing.hasMatch(t);
    final isSocialExemption = isSocialClarification || isSituationalInquiry || isWellbeingMatch;
    final isActivityOrSituational =
        _socialActivityInquiry.hasMatch(t) || isSituationalInquiry;
    final isCompoundGreetingInquiry =
        RegExp(r'^\s*(?:hola|hol|ola|buenas|buenos|hey|oe|saludos)\b', caseSensitive: false)
            .hasMatch(t) &&
        (isActivityOrSituational ||
            _socialInvitation.hasMatch(t) ||
            t.contains('?') &&
                !isWellbeingMatch &&
                !_simpleStateConcern.hasMatch(t));

    final narrativeDetected =
        _narrative.hasMatch(t) || (!isSocialExemption && signals.isCorrection);
    final isClarification = RegExp(
      r'^(?:[¿¡]?\s*(?:qu[eé]|c[oó]mo|qui[eé]n|cu[aá]l|d[oó]nde|por\s+qu[eé]|c[oó]mo\s+as[ií])[\s.,!?]*)$',
      caseSensitive: false,
    ).hasMatch(t);
    final contextualDetected =
        isCompoundGreetingInquiry ||
        isClarification ||
        (!isSocialExemption && (_anaphora.hasMatch(t) || signals.hasReference));
    final isSocialRefusal = _socialRefusal.hasMatch(t);
    final complexDetected =
        !isSocialRefusal &&
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
            isWellbeingMatch ||
            _reciprocalWellbeing.hasMatch(t) ||
            _socialActivityInquiry.hasMatch(t) ||
            _socialWellbeingReassurance.hasMatch(t) ||
            _socialInvitation.hasMatch(t) ||
            _pureEmotionalSocial.hasMatch(t) ||
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
