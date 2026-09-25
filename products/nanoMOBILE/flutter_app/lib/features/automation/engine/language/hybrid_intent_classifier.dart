// hybrid_intent_classifier.dart
//
// QUÉ HACE: Clasificador híbrido de intenciones (desde un "Hola" hasta párrafos grandes).
// CÓMO FUNCIONA: Segmenta párrafos largos en cláusulas (`_splitClauses`), evalúa raíces
//   subpalabra y patrones pragmáticos por oración y globalmente, sin requerir un LLM 7B.
// POR QUÉ: Evita que párrafos extensos diluyan la pregunta principal y mantiene <190 líneas (SOLID).

library;

import '../business/fact_selector.dart' show normalizeText, tokenizeText;

enum HybridIntentCategory {
  personalAppointmentOrPlan,
  personalProjectOrFact,
  contextualCoreference,
  externalCurrentKnowledge,
  correctionOrContradiction,
  ownerLiveState,
  socialEveryday,
  openComplexDialogue,
}

final class HybridIntentPrediction {
  final HybridIntentCategory primaryIntent;
  final Set<HybridIntentCategory> activeIntents;
  final double confidence;
  final List<String> extractedTopics;
  final String? temporalAnchor;
  final bool blocksLiteralStyleReuse;

  const HybridIntentPrediction({
    required this.primaryIntent,
    this.activeIntents = const {},
    required this.confidence,
    this.extractedTopics = const [],
    this.temporalAnchor,
    required this.blocksLiteralStyleReuse,
  });
}

final class HybridIntentClassifier {
  const HybridIntentClassifier();

  static const _corefMarkers = [
    'lo de la otra vez', 'lo de ayer', 'lo del otro dia', 'lo que hablamos',
    'lo que me dijiste', 'lo que te dije', 'eso que dijiste', 'yo decia lo de',
    'me referia a', 'hablaba de', 'el otro tema', 'sobre aquello', 'lo pendiente',
  ];

  static const _appointmentRoots = [
    'vernos', 'vemos', 'encontr', 'quedamos', 'cita', 'reunion', 'salir',
    'pasar por', 'ir manana', 'si vas', 'entonces si', 'confirm', 'parche',
    'almorzar', 'cenar', 'tomar algo', 'visitar',
  ];

  static const _projectRoots = [
    'aplicacion', 'app', 'proyecto', 'sistema', 'codigo', 'programa',
    'terminaste', 'acabaste', 'avanzaste', 'haciendo', 'desarrollando',
    'construyendo', 'trabajo', 'universidad', 'estudio', 'negocio',
  ];

  static const _externalRoots = [
    'saco google', 'saco apple', 'saco openai', 'saco meta', 'saco microsoft',
    'lo nuevo de', 'lo nuevo que saco', 'anuncio de', 'lanzamiento', ' salio hoy',
    'que paso con', 'noticias', 'precio del', 'cuanto esta el', 'clima',
    'partido', 'resultado de', 'actualizacion de', 'version de',
  ];

  static const _correctionRoots = [
    'no parce yo decia', 'no te pregunte eso', 'eso no es', 'me malinterpretaste',
    'no entendiste', 'te equivocaste', 'al reves', 'no era eso',
  ];

  static const _stopwords = {
    'el', 'la', 'los', 'las', 'un', 'una', 'de', 'del', 'a', 'en', 'con',
    'por', 'para', 'que', 'es', 'son', 'si', 'no', 'ya', 'o', 'y', 'pero',
    'como', 'cuando', 'donde', 'quien', 'cual', 'parce', 'bro', 'mano', 'oe',
    'hola', 'buenas', 'entonces', 'viste', 'sabes', 'decia', 'otra', 'vez',
    'hoy', 'ayer', 'manana', 'estabas', 'haciendo', 'nuevo', 'saco', 'lo',
  };

  /// Clasifica desde un saludo corto ("Hola") hasta párrafos extensos multi-oración.
  /// QUÉ HACE: Evalúa cada cláusula del mensaje y fusiona las intenciones detectadas.
  /// CÓMO FUNCIONA: Divide por signos de puntuación (`.`, `?`, `!`, `\n`, `;`), puntúa cada
  ///   oración y retiene el puntaje máximo por categoría, evitando dilución en textos largos.
  HybridIntentPrediction classify(String rawText) {
    final norm = normalizeText(rawText);
    final tokens = tokenizeText(norm);
    if (tokens.isEmpty) {
      return const HybridIntentPrediction(
        primaryIntent: HybridIntentCategory.socialEveryday,
        confidence: 0.5,
        blocksLiteralStyleReuse: false,
      );
    }

    final scores = <HybridIntentCategory, double>{};
    final clauses = _splitClauses(rawText);
    for (final clause in clauses) {
      _scoreClause(normalizeText(clause), scores);
    }
    _scoreClause(norm, scores);

    final temporal = _detectTemporalAnchor(norm);
    final topics = tokens
        .where((t) => t.length >= 3 && !_stopwords.contains(t))
        .take(8)
        .toList(growable: false);

    if (scores.isEmpty) {
      final isQuestionOrLong = rawText.contains('?') || tokens.length >= 7;
      final cat = isQuestionOrLong
          ? HybridIntentCategory.openComplexDialogue
          : HybridIntentCategory.socialEveryday;
      return HybridIntentPrediction(
        primaryIntent: cat,
        activeIntents: {cat},
        confidence: isQuestionOrLong ? 0.72 : 0.85,
        extractedTopics: topics,
        temporalAnchor: temporal,
        blocksLiteralStyleReuse: isQuestionOrLong,
      );
    }

    final sorted = scores.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final primary = sorted.first.key;
    return HybridIntentPrediction(
      primaryIntent: primary,
      activeIntents: sorted.where((e) => e.value >= 0.60).map((e) => e.key).toSet(),
      confidence: sorted.first.value,
      extractedTopics: topics,
      temporalAnchor: temporal,
      blocksLiteralStyleReuse: primary != HybridIntentCategory.socialEveryday,
    );
  }

  /// Evalúa una cláusula individual para detectar citas, proyectos, correferencias o actualidad.
  static void _scoreClause(String cNorm, Map<HybridIntentCategory, double> scores) {
    final cTokens = tokenizeText(cNorm);
    if (cTokens.isEmpty) return;
    final temporal = _detectTemporalAnchor(cNorm);
    if (_matchesAny(cNorm, _corefMarkers) || _hasCoreferencePattern(cNorm, cTokens)) {
      scores[HybridIntentCategory.contextualCoreference] = 0.92;
    }
    if (_matchesAny(cNorm, _correctionRoots)) {
      scores[HybridIntentCategory.correctionOrContradiction] = 0.90;
    }
    if (_scoreSubwordFamily(cNorm, cTokens, _appointmentRoots) >= 0.45 ||
        (temporal != null && (cNorm.contains('nos vemos') || cNorm.contains('si vas') || cNorm.contains('quedamos')))) {
      scores[HybridIntentCategory.personalAppointmentOrPlan] = 0.88;
    }
    if (_scoreSubwordFamily(cNorm, cTokens, _projectRoots) >= 0.45) {
      scores[HybridIntentCategory.personalProjectOrFact] = 0.86;
    }
    if (_scoreSubwordFamily(cNorm, cTokens, _externalRoots) >= 0.45 ||
        _hasExternalEntityLaunchPattern(cNorm, cTokens)) {
      scores[HybridIntentCategory.externalCurrentKnowledge] = 0.91;
    }
  }

  static List<String> _splitClauses(String raw) => raw
      .split(RegExp(r'[.?!;\n]+'))
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList(growable: false);

  static bool _matchesAny(String norm, List<String> phrases) => phrases.any(norm.contains);

  static bool _hasCoreferencePattern(String norm, Iterable<String> tokens) =>
      tokens.any((t) => t == 'aquello' || t == 'anterior' || t == 'pendiente' || t == 'hablamos') &&
      (norm.contains('lo de') || norm.contains('eso que'));

  static bool _hasExternalEntityLaunchPattern(String norm, Iterable<String> tokens) =>
      (norm.contains('saco ') || norm.contains('salio ') || norm.contains('anuncio ') || norm.contains('lanzo ')) &&
      tokens.any(const {'google', 'gemini', 'openai', 'chatgpt', 'deepseek', 'apple', 'android', 'meta', 'claude', 'nvidia', 'dolar', 'bitcoin'}.contains);

  static double _scoreSubwordFamily(String norm, Iterable<String> tokens, List<String> roots) {
    for (final r in roots) {
      if (norm.contains(r)) return 0.85;
      if (r.contains(' ')) continue;
      for (final t in tokens) {
        if (t.length >= 5 && r.length >= 5 && (t.startsWith(r.substring(0, 5)) || r.startsWith(t.substring(0, 5)))) {
          return 0.55;
        }
      }
    }
    return 0.0;
  }

  static String? _detectTemporalAnchor(String norm) {
    for (final a in const ['manana', 'ayer', 'hoy', 'otra vez', 'otro dia', 'esta semana', 'viernes', 'sabado', 'domingo']) {
      if (norm.contains(a)) return a;
    }
    return null;
  }
}
