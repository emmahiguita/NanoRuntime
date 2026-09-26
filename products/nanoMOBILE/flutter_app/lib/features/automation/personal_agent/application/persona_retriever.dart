// persona_retriever.dart
//
// QUÉ HACE:
// Recupera ejemplos de estilo y frases aprendidas desde SQLite FTS4 y almacén persistente.
//
// CÓMO FUNCIONA:
// - Clasifica la intención del turno con `ConversationalIntentClassifier`.
// - Consulta FTS4 y lista de ejemplos considerando la jerarquía de scopes:
//   1. Contacto específico -> 2. Rol personal -> 3. Propietario -> 4. Global.
// - Pondera con `HybridRetrievalScorer` (8 señales: exacto, variantes, FTS, léxico, semántico, intent, contexto).
//
// POR QUÉ:
// Asegura que intenciones y paráfrasis sin tokens idénticos se recuperen fielmente (< 175 líneas).

library;

import 'package:flutter/foundation.dart' show debugPrint;

import 'package:nanoai/features/automation/engine/language/conversational_intent_catalog.dart';
import 'package:nanoai/features/automation/engine/language/conversational_intent_classifier.dart';
import 'package:nanoai/features/automation/engine/language/intent_prediction.dart';
import '../domain/persona_example.dart';
import 'hybrid_retrieval_scorer.dart';
import 'persona_repository.dart';
import 'persona_retriever_scorer.dart';
import 'personal_learning_text.dart';

final class PersonaRetriever {
  PersonaRetriever({
    PersonaRepository? repository,
    ConversationalIntentClassifier? classifier,
    HybridRetrievalScorer? scorer,
  })  : _repository = repository ?? PersonaRepository.instance,
        _classifier = classifier ?? const ConversationalIntentClassifier(),
        _scorer = scorer ?? const HybridRetrievalScorer();

  final PersonaRepository _repository;
  final ConversationalIntentClassifier _classifier;
  final HybridRetrievalScorer _scorer;

  /// Delegado estático para compatibilidad con código existente.
  static double scorePatternMatch(String rawInput, String rawPattern) =>
      PersonaRetrieverScorer.scorePatternMatch(rawInput, rawPattern);

  /// Puntuación híbrida multi-señal [0.0..1.0] de un [example] frente al [context] actual.
  static double scoreExample(String context, PersonaExample example, [IntentPrediction? pred]) {
    final prediction = pred ?? const ConversationalIntentClassifier().classify(context).primaryIntent;
    return const HybridRetrievalScorer().score(
      rawInput: context,
      example: example,
      inputPrediction: prediction,
    );
  }

  /// Recupera ejemplos parecidos respetando la lista de ámbitos ordenada por precedencia.
  Future<List<PersonaExample>> retrieve(
    String context, {
    int limit = 2,
    String scopeKey = 'owner',
    String roleKey = 'role:personal',
    List<String>? candidateScopes,
  }) async {
    final sw = Stopwatch()..start();
    if (context.trim().isEmpty) return const [];

    final aggregated = _classifier.classify(context);
    final inputPrediction = aggregated.primaryIntent;

    // Si es una corrección dialógica explícita, se bloquea la reutilización literal
    if (inputPrediction.intentId == ConversationalIntentId.correction.id) {
      return const [];
    }

    final effectiveScopes = candidateScopes ?? [scopeKey, roleKey, 'owner', 'global'];
    final primaryScope = effectiveScopes.first;

    final indexed = await _repository.searchExamples(
      context,
      limit: 40,
      scopeKey: primaryScope,
      roleKey: roleKey,
    );

    final normalizedContext = normalizePersonalLearningText(context);
    final terms = PersonaRetrieverScorer.meaningfulTerms(normalizedContext);

    var indexedBest = 0.0;
    for (final example in indexed) {
      final current = _scorer.score(rawInput: context, example: example, inputPrediction: inputPrediction);
      if (current > indexedBest) indexedBest = current;
    }

    final needsVariantFallback =
        terms.length <= 8 && (indexed.isEmpty || indexedBest < 0.70);
    final stored = needsVariantFallback
        ? await _repository.listExamples(limit: 200)
        : const <PersonaExample>[];

    final byId = <int, PersonaExample>{
      for (final example in indexed) example.id: example,
      for (final example in stored) example.id: example,
    };
    final candidates = byId.values.toList();

    const minPairedRelevance = 0.40;
    final scoresById = <int, double>{
      for (final c in candidates)
        c.id: _scorer.score(
          rawInput: context,
          example: c,
          inputPrediction: inputPrediction,
        ),
    };

    final eligible = candidates.where((e) {
      if (!e.enabled) return false;
      if (!e.ownerVerified && !e.isTemplate) return false;
      if (!effectiveScopes.contains(e.personaKey) &&
          e.personaKey != 'owner' &&
          e.personaKey != 'global') {
        return false;
      }
      if (e.isPaired && (scoresById[e.id] ?? 0.0) < minPairedRelevance) {
        return false;
      }
      final src = e.source.toLowerCase();
      if (src.contains('nano') || src == 'assistant') return false;
      return true;
    }).toList();

    eligible.sort((a, b) {
      final relevance = (scoresById[b.id] ?? 0.0).compareTo(
        scoresById[a.id] ?? 0.0,
      );
      if (relevance != 0) return relevance;

      final idxA = effectiveScopes.indexOf(a.personaKey);
      final idxB = effectiveScopes.indexOf(b.personaKey);
      final orderA = idxA >= 0 ? idxA : 999;
      final orderB = idxB >= 0 ? idxB : 999;
      final scopeOrder = orderA.compareTo(orderB);
      if (scopeOrder != 0) return scopeOrder;

      if (a.isPaired != b.isPaired) return a.isPaired ? -1 : 1;
      return b.id.compareTo(a.id);
    });

    sw.stop();
    debugPrint('[personal-retriever] latency=${sw.elapsedMicroseconds / 1000.0}ms candidates=${candidates.length} eligible=${eligible.length}');

    return eligible.take(limit.clamp(1, 4)).toList();
  }
}
