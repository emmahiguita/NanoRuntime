// intent_prediction.dart
//
// QUÉ HACE:
// Modelo canónico y unificado de predicción semántica e intenciones para Nano Personal.
//
// CÓMO FUNCIONA:
// Encapsula intención primaria, granularidad fina (IntentId), evidencia trazable,
// entidades, anclajes temporales, polaridad y banderas de guardia (Live State, Contexto).
//
// POR QUÉ:
// Proporciona un DTO inmutable estándar que desacopla la extracción NLU del consumo
// conversacional en Clean Architecture, manteniendo el código en < 140 líneas.

library;

enum IntentPolarity {
  positive,
  negative,
  uncertain;

  static IntentPolarity fromText(String text) {
    final lower = text.toLowerCase()
        .replaceAll(RegExp(r'[áàäâ]'), 'a')
        .replaceAll(RegExp(r'[éèëê]'), 'e')
        .replaceAll(RegExp(r'[íìïî]'), 'i')
        .replaceAll(RegExp(r'[óòöô]'), 'o')
        .replaceAll(RegExp(r'[úùüû]'), 'u');
    if (lower.contains('todavia no') ||
        lower.contains('no se') ||
        lower.contains('puede que') ||
        lower.contains('tal vez') ||
        lower.contains('de pronto')) {
      return IntentPolarity.uncertain;
    }
    if (lower.contains('no ') || lower.startsWith('no') || lower.contains('creo que no')) {
      return IntentPolarity.negative;
    }
    return IntentPolarity.positive;
  }
}

final class IntentEvidence {
  final String source; // 'exact', 'storedVariant', 'fts', 'lexical', 'semantic', 'pragmatic', 'context'
  final double score;
  final String detail;

  const IntentEvidence({
    required this.source,
    required this.score,
    required this.detail,
  });

  @override
  String toString() => '$source:$score($detail)';
}

final class IntentPrediction {
  final String macroIntent;
  final String intentId;
  final double confidence;
  final List<String> topics;
  final Map<String, String> entities;
  final String? temporalAnchor;
  final IntentPolarity polarity;
  final bool needsContext;
  final bool needsClarification;
  final bool requiresLiveState;
  final List<IntentEvidence> evidence;

  const IntentPrediction({
    required this.macroIntent,
    required this.intentId,
    required this.confidence,
    this.topics = const [],
    this.entities = const {},
    this.temporalAnchor,
    this.polarity = IntentPolarity.positive,
    this.needsContext = false,
    this.needsClarification = false,
    this.requiresLiveState = false,
    this.evidence = const [],
  });

  static const unknown = IntentPrediction(
    macroIntent: 'openComplexDialogue',
    intentId: 'unknown',
    confidence: 0.0,
  );
}

final class ClauseIntentPrediction {
  final String clause;
  final IntentPrediction prediction;

  const ClauseIntentPrediction({
    required this.clause,
    required this.prediction,
  });
}

final class AggregatedIntentPrediction {
  final IntentPrediction primaryIntent;
  final List<IntentPrediction> secondaryIntents;
  final List<ClauseIntentPrediction> clausePredictions;
  final double overallConfidence;

  const AggregatedIntentPrediction({
    required this.primaryIntent,
    this.secondaryIntents = const [],
    this.clausePredictions = const [],
    required this.overallConfidence,
  });
}
