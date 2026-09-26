// hybrid_retrieval_scorer.dart
//
// QUÉ HACE:
// Motor de puntuación multi-señal para el ranking y recuperación de ejemplos de Nano Personal.
//
// CÓMO FUNCIONA:
// Pondera 8 señales independientes: coincidencia exacta, variante aprendida, FTS4, similitud
// léxica, similitud semántica, compatibilidad de intención, compatibilidad contextual y prioridad de scope.
//
// POR QUÉ:
// Supera las limitaciones de Jaccard/FTS4 puro sin recurrir a un modelo pesado y permite calibrar
// pesos de forma centralizada y auditable (SOLID - SRP) en < 180 líneas.

library;

import 'package:nanoai/features/automation/engine/language/conversational_intent_catalog.dart';
import 'package:nanoai/features/automation/engine/language/intent_prediction.dart';
import 'package:nanoai/features/automation/engine/language/semantic_similarity_engine.dart';
import 'package:nanoai/features/automation/personal_agent/domain/persona_example.dart';
import 'personal_learning_text.dart' show normalizePersonalLearningText;

final class HybridScorerWeights {
  final double exact;
  final double storedVariant;
  final double fts;
  final double lexical;
  final double semantic;
  final double intent;
  final double context;

  const HybridScorerWeights({
    this.exact = 0.25,
    this.storedVariant = 0.25,
    this.fts = 0.10,
    this.lexical = 0.10,
    this.semantic = 0.15,
    this.intent = 0.10,
    this.context = 0.05,
  });
}

final class HybridRetrievalScorer {
  final HybridScorerWeights weights;
  final SemanticSimilarityEngine similarityEngine;

  const HybridRetrievalScorer({
    this.weights = const HybridScorerWeights(),
    this.similarityEngine = const LightweightSemanticSimilarityEngine(),
  });

  /// Evalúa la afinidad global [0.0..1.0] entre el mensaje entrante y un ejemplo de estilo/par.
  double score({
    required String rawInput,
    required PersonaExample example,
    required IntentPrediction inputPrediction,
    double ftsRawScore = 0.0,
    bool hasContextualContinuity = false,
  }) {
    final normInput = normalizePersonalLearningText(rawInput);
    final normStored = normalizePersonalLearningText(example.incomingText);
    if (normInput.isEmpty) return 0.0;

    // 1. Coincidencia exacta con el disparador principal
    final exactMatch = (normStored.isNotEmpty && normInput == normStored) ? 1.0 : 0.0;

    // 2. Coincidencia con variantes aprendidas en el Studio
    var variantMatch = 0.0;
    for (final v in example.incomingVariants) {
      final normV = normalizePersonalLearningText(v);
      if (normV.isNotEmpty && normInput == normV) {
        variantMatch = 1.0;
        break;
      }
    }

    // 3. Similitud semántica pragmática (paráfrasis / sinónimos)
    final semanticScore = LightweightSemanticSimilarityEngine.compute(rawInput, example.incomingText);

    // 4. Similitud léxica basada en tokens significativos
    final lexicalScore = _computeLexicalOverlap(normInput, normStored);

    // 5. Compatibilidad de intención predicha vs intención almacenada
    final storedIntent = ConversationalIntentId.fromId(example.tone['intent']);
    var intentScore = 0.50; // Neutral si el ejemplo no tiene intención tipificada
    if (storedIntent != ConversationalIntentId.unknown) {
      intentScore = (inputPrediction.intentId == storedIntent.id) ? 1.0 : 0.10;
    }

    // 6. Contexto y elipsis
    final contextScore = hasContextualContinuity ? 1.0 : 0.0;

    // Suma ponderada de señales normalizadas con bifurcación de match aprendido vs paráfrasis
    var totalScore = 0.0;
    if (exactMatch == 1.0 || variantMatch == 1.0) {
      final base = exactMatch == 1.0 ? 0.92 : 0.88;
      totalScore = (base + (0.05 * intentScore) + (0.03 * semanticScore)).clamp(0.0, 1.0);
    } else {
      totalScore = (
        (weights.semantic * 2.5 * semanticScore) +
        (weights.intent * 3.0 * intentScore) +
        (weights.lexical * 1.5 * lexicalScore) +
        (weights.fts * ftsRawScore.clamp(0.0, 1.0)) +
        (weights.context * contextScore)
      ).clamp(0.0, 1.0);
    }

    // Penalización estricta por inversión de polaridad ("si voy" vs "no voy")
    if (example.incomingText.isNotEmpty) {
      final storedPolarity = IntentPolarity.fromText(example.incomingText);
      if (inputPrediction.polarity != storedPolarity) {
        totalScore *= 0.15;
      }
    }

    // Guardia de estado vivo (Live State Guard)
    if (inputPrediction.requiresLiveState && (example.source != 'live_verified')) {
      totalScore *= 0.20;
    }

    return totalScore.clamp(0.0, 1.0);
  }

  static double _computeLexicalOverlap(String a, String b) {
    if (a.isEmpty || b.isEmpty) return 0.0;
    final setA = a.split(' ').where((t) => t.length > 2).toSet();
    final setB = b.split(' ').where((t) => t.length > 2).toSet();
    if (setA.isEmpty || setB.isEmpty) return 0.0;
    final inter = setA.intersection(setB).length;
    final union = setA.union(setB).length;
    return union > 0 ? inter / union : 0.0;
  }
}
