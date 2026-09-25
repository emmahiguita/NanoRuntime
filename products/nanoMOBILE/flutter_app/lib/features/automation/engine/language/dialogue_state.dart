// dialogue_state.dart
//
// QUÉ HACE:
// Representación explícita del estado del diálogo y análisis lingüístico determinista (0 LLM)
// en español para turnos individuales y compuestos.
//
// CÓMO FUNCIONA:
// 1. Detecta negaciones gramaticales y extrae sobre qué recae la negación (`negationScope`, `negatedAttribute`).
// 2. Identifica correcciones activas vinculando origen y destino (`correctionTarget`).
// 3. Resuelve expresiones anafóricas ("ese", "el otro", "lo de ayer") hacia el contexto.
// 4. Clasifica la multiplicidad de intenciones del turno (precio + disponibilidad + despacho).
//
// POR QUÉ:
// Evita que el agente asuma que una negación ("no quiero el rojo") descarta toda la compra;
// delimita con precisión el atributo rechazado manteniendo el interés en el producto.

library;

/// Acto comunicativo principal inferido del mensaje.
enum DialogueAct {
  greeting, socialCheckin, technicalInquiry, commercialInquiry,
  correction, negation, clarification, closure, multiIntent, general,
}

/// Señales lingüísticas extraídas deterministamente de un turno.
final class LinguisticSignals {
  final bool hasNegation;
  final String? negationScope;
  final String? negatedAttribute; // 'color', 'modelo', 'envio', 'compra', 'tiempo'
  final bool isCorrection;
  final String? correctionTarget;
  final bool hasReference;
  final String? referenceCandidate;
  final bool isMultiIntent;
  final List<String> detectedIntents;
  final String tense;

  const LinguisticSignals({
    this.hasNegation = false,
    this.negationScope,
    this.negatedAttribute,
    this.isCorrection = false,
    this.correctionTarget,
    this.hasReference = false,
    this.referenceCandidate,
    this.isMultiIntent = false,
    this.detectedIntents = const [],
    this.tense = 'presente',
  });
}

/// Analizador lingüístico determinista para español.
final class LinguisticAnalyzer {
  const LinguisticAnalyzer();

  static final _negationPatterns = [
    RegExp(r'\bno\s+(?:quiero|deseo|necesito|voy a|pienso)\s+([^,;.\n]+)', caseSensitive: false),
    RegExp(r'\bno\s+(?:es|era|seria)\s+(?:el|la|los|las)?\s*([^,;.\n]+)', caseSensitive: false),
    RegExp(r'\bya\s+no\s+([^,;.\n]+)', caseSensitive: false),
    RegExp(r'\bno\s+([^,;.\n]+)', caseSensitive: false),
  ];

  static final _correctionPatterns = [
    RegExp(r'\b(?:no,?\s+)?(?:me\s+refer[íi]a|quise\s+decir|quise\s+referirme|hablo\s+de)\s+(?:al?|la|el|los|las)?\s*([^,;.\n]+)', caseSensitive: false),
    RegExp(r'\b(?:no,?\s+es|no\s+era)\s+([^,;.\n]+)', caseSensitive: false),
  ];

  static final _anaphoraPatterns = [
    RegExp(r'\b(ese|esa|esos|esas|el\s+otro|la\s+otra|aquel|aquella)\b', caseSensitive: false),
    RegExp(r'\b(sobre\s+eso|de\s+eso|lo\s+que\s+dijiste|lo\s+de\s+ayer|el\s+mismo|ese\s+mismo)\b', caseSensitive: false),
  ];

  static final _pastTensePatterns = RegExp(
    r'\b(funcionaba|serv[íi]a|compr[ée]|pagu[ée]|instal[ée]|prob[ée]|dije|hablamos|ayer|antes)\b',
    caseSensitive: false,
  );

  static final _futureTensePatterns = RegExp(
    r'\b(mañana|despu[ée]s|luego|voy\s+a|vas\s+a|iremos|har[ée]|mandar[íi]an)\b',
    caseSensitive: false,
  );

  /// Analiza el texto y extrae sus dimensiones y anclajes semánticos.
  LinguisticSignals analyze(String rawText) {
    final text = rawText.trim();
    if (text.isEmpty) return const LinguisticSignals();
    final lower = text.toLowerCase();

    // 1. Corrección y foco
    var isCorrection = false;
    String? correctionTarget;
    for (final pat in _correctionPatterns) {
      final match = pat.firstMatch(lower);
      if (match != null) {
        isCorrection = true;
        correctionTarget = match.group(1)?.trim();
        break;
      }
    }

    // 2. Negación y alcance específico
    var hasNegation = false;
    String? negationScope;
    String? negatedAttr;
    if (lower.startsWith('no ') || lower.contains(' no ') || lower.contains('ya no ')) {
      hasNegation = true;
      for (final pat in _negationPatterns) {
        final match = pat.firstMatch(lower);
        if (match != null) {
          negationScope = match.group(1)?.trim();
          negatedAttr = _classifyNegatedAttribute(negationScope);
          break;
        }
      }
    }

    // 3. Referencia anafórica
    var hasReference = false;
    String? referenceCandidate;
    for (final pat in _anaphoraPatterns) {
      final match = pat.firstMatch(lower);
      if (match != null) {
        hasReference = true;
        referenceCandidate = match.group(1)?.trim();
        break;
      }
    }

    // 4. Multi-intenciones articuladas (personales, sociales y comerciales)
    final intents = <String>[];
    if (RegExp(r'\b(hola|buenas|buenos dias|tardes|noches|hey|quiubo)\b').hasMatch(lower)) {
      intents.add('saludo');
    }
    if (RegExp(r'\b(bro|brother|parce|parcero|amigo|amiga|hermano|pana|amor|socio)\b').hasMatch(lower)) {
      intents.add('relacion_social');
    }
    if (RegExp(r'\b(qu[eé]\s+haces|haciendo|vas\s+a\s+salir|qu[eé]\s+planes|en\s+qu[eé]\s+andas|qu[eé]\s+cuentas)\b').hasMatch(lower)) {
      intents.add('pregunta_actividad');
    }
    if (RegExp(r'\b(hablaste\s+con|viste\s+a|le\s+dijiste\s+a|llamaste\s+a|con\s+[a-záéíóúñ]{3,})\b').hasMatch(lower)) {
      intents.add('referencia_persona');
    }
    if (RegExp(r'\b(ya\s+hablaste|todav[ií]a|a[uú]n|al\s+final|si\s+pudiste|qu[eé]\s+pas[oó]\s+con|c[oó]mo\s+qued[oó])\b').hasMatch(lower)) {
      intents.add('continuidad');
    }
    if (RegExp(r'\b(puedes|podr[ií]as|ay[uú]dame|m[aá]ndame|av[ií]same|dime)\b').hasMatch(lower)) {
      intents.add('solicitud');
    }
    if (RegExp(r'\b(precio|cuanto|cuánto|vale|cuesta|valor)\b').hasMatch(lower)) intents.add('precio');
    if (RegExp(r'\b(tienen|tienes|disponible|hay|stock|queda)\b').hasMatch(lower)) intents.add('disponibilidad');
    if (RegExp(r'\b(env[ií]os?|mandan|mandar|domicilios?|entregan?|entregas?|llegar)\b').hasMatch(lower)) intents.add('envio');

    final substantiveCount = intents
        .where((i) => i != 'saludo' && i != 'relacion_social')
        .length;
    final isMultiIntent =
        substantiveCount >= 2 || (intents.contains('saludo') && substantiveCount >= 1 && intents.length >= 3);

    // 5. Tiempo verbal predominante
    var tense = 'presente';
    if (_pastTensePatterns.hasMatch(lower)) {
      tense = 'pasado';
    } else if (_futureTensePatterns.hasMatch(lower)) {
      tense = 'futuro';
    }

    return LinguisticSignals(
      hasNegation: hasNegation,
      negationScope: negationScope,
      negatedAttribute: negatedAttr,
      isCorrection: isCorrection,
      correctionTarget: correctionTarget,
      hasReference: hasReference,
      referenceCandidate: referenceCandidate,
      isMultiIntent: isMultiIntent,
      detectedIntents: intents,
      tense: tense,
    );
  }

  /// Identifica sobre qué categoría recae la negación para no invalidar el turno completo.
  String? _classifyNegatedAttribute(String? scope) {
    if (scope == null) return null;
    if (RegExp(r'\b(negro|blanco|azul|rojo|verde|grande|chico|pequeño|pro|max)\b').hasMatch(scope)) return 'variante';
    if (RegExp(r'\b(envio|envío|domicilio|bello|medellin|bogota|casa)\b').hasMatch(scope)) return 'envio';
    if (RegExp(r'\b(caro|costoso|pagar|plata|dinero)\b').hasMatch(scope)) return 'precio';
    if (RegExp(r'\b(comprar|cancelar|pedir|llevar)\b').hasMatch(scope)) return 'accion';
    return 'general';
  }
}

const linguisticAnalyzer = LinguisticAnalyzer();
