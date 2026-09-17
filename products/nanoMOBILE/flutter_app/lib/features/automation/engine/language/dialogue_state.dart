/// WA-DIALOGUE-STATE-01 — Representación explícita del estado del diálogo
/// y análisis lingüístico determinista (0 LLM) para español.
///
/// Detecta dimensiones semánticas clave:
/// - Negación y su alcance ("no quiero cancelar", "ya no se cierra").
/// - Correcciones activas ("no, me refería al móvil").
/// - Referencias anafóricas ("ese", "el otro", "sobre eso").
/// - Múltiples intenciones ("cuánto vale y hacen envíos?").
/// - Tiempos verbales relevantes (pasado / presente / futuro).
library;

/// Acto comunicativo principal inferido del mensaje.
enum DialogueAct {
  greeting,
  socialCheckin,
  reciprocalQuestion,
  userWellbeing,
  technicalInquiry,
  commercialInquiry,
  correction,
  negation,
  clarification,
  closure,
  multiIntent,
  general,
}

/// Señales lingüísticas extraídas deterministamente de un turno.
final class LinguisticSignals {
  /// Contiene una negación gramatical o léxica explícita.
  final bool hasNegation;

  /// Frase o segmento alcanzado por la negación (ej. "cancelar" en "no quiero cancelar").
  final String? negationScope;

  /// El usuario está corrigiendo una interpretación o turno previo ("no, me refería a").
  final bool isCorrection;

  /// Término u objetivo de la corrección ("móvil" en "no, me refería al móvil").
  final String? correctionTarget;

  /// Contiene referencias anafóricas a entidades del contexto ("ese", "el otro", "sobre eso").
  final bool hasReference;

  /// Término referencial detectado.
  final String? referenceCandidate;

  /// Múltiples intenciones o solicitudes en el mismo mensaje.
  final bool isMultiIntent;

  /// Intenciones identificadas en el turno compuesto.
  final List<String> detectedIntents;

  /// Señal temporal predominante (pasado, presente, futuro).
  final String tense;

  const LinguisticSignals({
    this.hasNegation = false,
    this.negationScope,
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
    RegExp(r'\bno\s+(?:quiero|deseo|necesito|voy a|pienso|solicito)\s+([^,;.\n]+)', caseSensitive: false),
    RegExp(r'\bya\s+no\s+([^,;.\n]+)', caseSensitive: false),
    RegExp(r'\bno\s+([^,;.\n]+)', caseSensitive: false),
  ];

  static final _correctionPatterns = [
    RegExp(r'\b(?:no,?\s+)?(?:me\s+refer[íi]a|quise\s+decir|quise\s+referirme|era|hablo\s+de)\s+(?:al?|la|el|los|las)?\s*([^,;.\n]+)', caseSensitive: false),
    RegExp(r'\b(?:no,?\s+es|no\s+era)\s+([^,;.\n]+)', caseSensitive: false),
  ];

  static final _anaphoraPatterns = [
    RegExp(r'\b(ese|esa|esos|esas|el\s+otro|la\s+otra|los\s+otros|las\s+otras|aquel|aquella)\b', caseSensitive: false),
    RegExp(r'\b(sobre\s+eso|de\s+eso|a\s+eso|lo\s+de\s+ayer|lo\s+que\s+dijiste)\b', caseSensitive: false),
  ];

  static final _pastTensePatterns = RegExp(
    r'\b(funcionaba|serv[íi]a|compr[ée]|pagu[ée]|instal[ée]|prob[ée]|dije|hablamos|ayer|antes|anoche|pasado)\b',
    caseSensitive: false,
  );

  static final _futureTensePatterns = RegExp(
    r'\b(mañana|despu[ée]s|luego|voy\s+a|vas\s+a|iremos|har[ée]|har[áa]s)\b',
    caseSensitive: false,
  );

  /// Analiza el texto normalizado y extrae sus dimensiones lingüísticas.
  LinguisticSignals analyze(String rawText) {
    final text = rawText.trim();
    if (text.isEmpty) return const LinguisticSignals();

    final lower = text.toLowerCase();

    // 1. Corrección
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

    // 2. Negación y contraejemplo
    var hasNegation = false;
    String? negationScope;
    if (lower.startsWith('no ') || lower.contains(' no ') || lower.contains('ya no ')) {
      hasNegation = true;
      for (final pat in _negationPatterns) {
        final match = pat.firstMatch(lower);
        if (match != null) {
          negationScope = match.group(1)?.trim();
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

    // 4. Detección de multi-intenciones (ej. precio + envío, saludo + pregunta técnica)
    final intents = <String>[];
    if (lower.contains('precio') ||
        lower.contains('cuanto vale') ||
        lower.contains('cuánto vale') ||
        lower.contains('cuanto cuesta') ||
        lower.contains('cuánto cuesta') ||
        lower.contains('valor')) {
      intents.add('precio');
    }
    if (lower.contains('envio') ||
        lower.contains('envío') ||
        lower.contains('envíos') ||
        lower.contains('domicilio') ||
        lower.contains('entregan')) {
      intents.add('envio');
    }
    if (lower.contains('ayuda') ||
        lower.contains('no abre') ||
        lower.contains('se cierra') ||
        lower.contains('falla') ||
        lower.contains('error')) {
      intents.add('soporte');
    }
    if (lower.contains('hola') || lower.contains('buenas') || lower.contains('hey')) {
      intents.add('saludo');
    }
    final isMultiIntent = intents.length >= 2;

    // 5. Tiempo verbal
    var tense = 'presente';
    if (_pastTensePatterns.hasMatch(lower)) {
      tense = 'pasado';
    } else if (_futureTensePatterns.hasMatch(lower)) {
      tense = 'futuro';
    }

    return LinguisticSignals(
      hasNegation: hasNegation,
      negationScope: negationScope,
      isCorrection: isCorrection,
      correctionTarget: correctionTarget,
      hasReference: hasReference,
      referenceCandidate: referenceCandidate,
      isMultiIntent: isMultiIntent,
      detectedIntents: intents,
      tense: tense,
    );
  }
}

const linguisticAnalyzer = LinguisticAnalyzer();
