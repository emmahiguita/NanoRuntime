// persona_retriever_scorer.dart
//
// QUÉ HACE:
// Cálculo de similitud estructural y ponderación semántica de patrones para el retriever.
//
// CÓMO FUNCIONA:
// - Pondera tokens específicos 5x por encima de saludos y vocativos genéricos.
// - Penaliza asimetrías de intención (ej. "¿hola?" ante "¿qué haces?").
// - Soporta similitud de paráfrasis pragmática e intersección ponderada Jaccard.
//
// POR QUÉ:
// Mantiene `persona_retriever.dart` por debajo de 180 líneas aplicando SRP (SOLID).

library;

import '../../engine/language/conversation_semantic_tag.dart';
import '../../engine/messaging/social_context_retriever.dart';
import 'personal_learning_text.dart';

import 'package:nanoai/features/automation/engine/language/semantic_similarity_engine.dart';

abstract final class PersonaRetrieverScorer {
  static const Set<String> genericGreetingOrVocativeTokens = {
    'hola', 'holi', 'holas', 'ola', 'buenas', 'buenos', 'buen', 'dia', 'dias',
    'tardes', 'noches', 'hey', 'oe', 'quiubo', 'saludos', 'bro', 'brother',
    'mano', 'manito', 'parcero', 'parce', 'pana', 'amigo', 'amiga', 'amor',
    'pa', 'ma', 'jefe', 'socio', 'emma', 'emmanuel',
  };

  static double scorePatternMatch(String rawInput, String rawPattern) {
    final normalizedInput = normalizePersonalLearningText(rawInput);
    final normalizedPattern = normalizePersonalLearningText(rawPattern);
    if (normalizedInput.isEmpty || normalizedPattern.isEmpty) return 0.0;

    if (normalizedInput == normalizedPattern) return 1.0;

    final semanticSim = LightweightSemanticSimilarityEngine.compute(rawInput, rawPattern);
    if (semanticSim >= 0.85) return semanticSim;

    final paraphrase = SocialContextRetriever.scoreParaphraseSimilarity(
      rawInput,
      rawPattern,
    );
    if (paraphrase >= 0.80) return paraphrase;

    final inputTerms = meaningfulTerms(normalizedInput);
    final patternTerms = meaningfulTerms(normalizedPattern);
    if (inputTerms.isEmpty || patternTerms.isEmpty) return 0.0;

    final specificInput = inputTerms.difference(genericGreetingOrVocativeTokens);
    final specificPattern = patternTerms.difference(genericGreetingOrVocativeTokens);
    final specificIntersection = specificInput.intersection(specificPattern);
    final genericIntersection = inputTerms
        .intersection(patternTerms)
        .intersection(genericGreetingOrVocativeTokens);

    final inputSemantic = ConversationSemanticClassifier.classify(rawInput);
    final patternSemantic = ConversationSemanticClassifier.classify(rawPattern);
    final inputIsQuestion =
        rawInput.contains('?') || inputSemantic == ConversationSemanticTag.question;
    final patternIsQuestion =
        rawPattern.contains('?') || patternSemantic == ConversationSemanticTag.question;

    final hasIntentLoss =
        (inputIsQuestion && !patternIsQuestion) ||
        (specificInput.isNotEmpty && specificPattern.isEmpty) ||
        (inputSemantic != ConversationSemanticTag.greeting &&
            patternSemantic == ConversationSemanticTag.greeting &&
            specificIntersection.isEmpty);

    final intersectionWeight =
        (specificIntersection.length * 2.5) + (genericIntersection.length * 0.5);
    final unionSpecific = specificInput.union(specificPattern).length;
    final unionGeneric = inputTerms
        .union(patternTerms)
        .intersection(genericGreetingOrVocativeTokens)
        .length;
    final unionWeight = (unionSpecific * 2.5) + (unionGeneric * 0.5);
    final weightedJaccard =
        unionWeight > 0 ? intersectionWeight / unionWeight : 0.0;

    final specificCoverage = specificInput.isEmpty
        ? (specificPattern.isEmpty ? 1.0 : 0.0)
        : specificIntersection.length / specificInput.length;

    double baseScore;
    if (!hasIntentLoss &&
        (inputSemantic == patternSemantic || specificCoverage == 1.0) &&
        specificCoverage >= 0.75) {
      baseScore = 0.76 + (0.19 * weightedJaccard);
    } else if (specificIntersection.isNotEmpty) {
      final phraseBonus =
          (normalizedInput.contains(normalizedPattern) ||
              normalizedPattern.contains(normalizedInput))
          ? 0.06
          : 0.0;
      baseScore = 0.50 + (0.24 * weightedJaccard) + phraseBonus;
    } else if (genericIntersection.isNotEmpty) {
      baseScore = 0.32 * weightedJaccard;
    } else if (normalizedInput.startsWith(normalizedPattern) ||
        normalizedInput.contains(normalizedPattern)) {
      baseScore = 0.18 * (patternTerms.length / inputTerms.length);
    } else {
      return 0.0;
    }

    final uncoveredSpecific = specificInput.difference(specificPattern).length;
    if (uncoveredSpecific > 0) {
      final lengthRatio = patternTerms.length < inputTerms.length
          ? patternTerms.length / inputTerms.length
          : 1.0;
      baseScore *= (1.0 / (1.0 + (0.65 * uncoveredSpecific))) * lengthRatio;
    }

    if (hasIntentLoss) {
      baseScore *= 0.25;
    }

    return baseScore.clamp(0.0, 1.0);
  }

  static Set<String> meaningfulTerms(String normalized) {
    const shortSignals = {'si', 'no', 'ok', 'ya', 'yo', 'tu', 'vos'};
    final terms = normalized
        .split(' ')
        .where((term) => term.length > 2 || shortSignals.contains(term))
        .toSet();
    if (terms.isEmpty && normalized.isNotEmpty) terms.add(normalized);
    return terms;
  }
}
