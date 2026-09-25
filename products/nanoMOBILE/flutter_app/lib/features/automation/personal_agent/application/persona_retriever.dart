/// PERSONA-RETRIEVAL-07 — retriever de ejemplos de estilo.
///
/// Sin embeddings (V1): FTS4 puro en SQLite. El texto del mensaje entrante
/// es la query; los ejemplos más parecidos guían al modelo en el prompt.
/// La selección es determinista (MATCH FTS + recencia) — jamás un vector
/// generado ni una puntuación del LLM.
library;

import '../../engine/language/conversation_semantic_tag.dart';
import '../../engine/messaging/social_context_retriever.dart';
import '../domain/persona_example.dart';
import 'persona_repository.dart';
import 'personal_learning_text.dart';

final class PersonaRetriever {
  PersonaRetriever({PersonaRepository? repository})
    : _repository = repository ?? PersonaRepository.instance;

  final PersonaRepository _repository;

  static const Set<String> _genericGreetingOrVocativeTokens = {
    'hola', 'holi', 'holas', 'ola', 'buenas', 'buenos', 'buen', 'dia', 'dias',
    'tardes', 'noches', 'hey', 'oe', 'quiubo', 'saludos', 'bro', 'brother',
    'mano', 'manito', 'parcero', 'parce', 'pana', 'amigo', 'amiga', 'amor',
    'pa', 'ma', 'jefe', 'socio', 'emma', 'emmanuel',
  };

  /// Calcula la similitud estructural [0.0..1.0] siguiendo la jerarquía (Ciclos 2 y 18).
  static double scorePatternMatch(String rawInput, String rawPattern) {
    final normalizedInput = normalizePersonalLearningText(rawInput);
    final normalizedPattern = normalizePersonalLearningText(rawPattern);
    if (normalizedInput.isEmpty || normalizedPattern.isEmpty) return 0.0;

    // 1. Exact semantic match
    if (normalizedInput == normalizedPattern) return 1.0;

    // 2. Paráfrasis pragmática equivalente sin tokens compartidos (Ciclo 18)
    final paraphrase = SocialContextRetriever.scoreParaphraseSimilarity(
      rawInput,
      rawPattern,
    );
    if (paraphrase >= 0.80) return paraphrase;

    final inputTerms = _meaningfulTerms(normalizedInput);
    final patternTerms = _meaningfulTerms(normalizedPattern);
    if (inputTerms.isEmpty || patternTerms.isEmpty) return 0.0;

    final specificInput = inputTerms.difference(_genericGreetingOrVocativeTokens);
    final specificPattern = patternTerms.difference(_genericGreetingOrVocativeTokens);
    final specificIntersection = specificInput.intersection(specificPattern);
    final genericIntersection = inputTerms
        .intersection(patternTerms)
        .intersection(_genericGreetingOrVocativeTokens);

    final inputSemantic = ConversationSemanticClassifier.classify(rawInput);
    final patternSemantic = ConversationSemanticClassifier.classify(rawPattern);
    final inputIsQuestion =
        rawInput.contains('?') || inputSemantic == ConversationSemanticTag.question;
    final patternIsQuestion =
        rawPattern.contains('?') || patternSemantic == ConversationSemanticTag.question;

    // Pérdida de intención: la entrada pregunta o trae carga específica y el
    // patrón se queda sólo en un saludo o pierde la interrogación.
    final hasIntentLoss =
        (inputIsQuestion && !patternIsQuestion) ||
        (specificInput.isNotEmpty && specificPattern.isEmpty) ||
        (inputSemantic != ConversationSemanticTag.greeting &&
            patternSemantic == ConversationSemanticTag.greeting &&
            specificIntersection.isEmpty);

    // Pesos diferenciados: tokens específicos valen 5x más que vocativos/saludos genéricos.
    final intersectionWeight =
        (specificIntersection.length * 2.5) + (genericIntersection.length * 0.5);
    final unionSpecific = specificInput.union(specificPattern).length;
    final unionGeneric = inputTerms
        .union(patternTerms)
        .intersection(_genericGreetingOrVocativeTokens)
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
      // 2. Intent + semantic similarity (ej. "hola, ¿qué haces?" vs "¿qué haces?")
      baseScore = 0.76 + (0.19 * weightedJaccard);
    } else if (specificIntersection.isNotEmpty) {
      // 3. Specific phrase overlap
      final phraseBonus =
          (normalizedInput.contains(normalizedPattern) ||
              normalizedPattern.contains(normalizedInput))
          ? 0.06
          : 0.0;
      baseScore = 0.50 + (0.24 * weightedJaccard) + phraseBonus;
    } else if (genericIntersection.isNotEmpty) {
      // 4. Generic token overlap (solo coincide en "hola", "bro", etc.)
      baseScore = 0.32 * weightedJaccard;
    } else if (normalizedInput.startsWith(normalizedPattern) ||
        normalizedInput.contains(normalizedPattern)) {
      // 5. Substring / prefix match puro
      baseScore = 0.18 * (patternTerms.length / inputTerms.length);
    } else {
      return 0.0;
    }

    // Penalización general por tokens específicos de la entrada no cubiertos por el ejemplo
    final uncoveredSpecific = specificInput.difference(specificPattern).length;
    if (uncoveredSpecific > 0) {
      final lengthRatio = patternTerms.length < inputTerms.length
          ? patternTerms.length / inputTerms.length
          : 1.0;
      baseScore *= (1.0 / (1.0 + (0.65 * uncoveredSpecific))) * lengthRatio;
    }

    // Penalización severa por pérdida de intención (ej. "hola" ante "hola, ¿qué haces?")
    if (hasIntentLoss) {
      baseScore *= 0.25;
    }

    return baseScore.clamp(0.0, 1.0);
  }

  /// Mejor puntuación [0.0..1.0] de un [example] frente al [context] actual.
  static double scoreExample(String context, PersonaExample example) {
    var best = 0.0;
    final patterns = <String>{
      if (example.incomingText.trim().isNotEmpty) example.incomingText.trim(),
      ...example.incomingVariants,
    };
    for (final pattern in patterns) {
      final current = scorePatternMatch(context, pattern);
      if (current > best) best = current;
    }
    return best;
  }

  /// Ejemplos parecidos al contexto (máx [limit], típicamente 2: el prompt
  /// WA ya es denso y cada ejemplo consume tokens).
  Future<List<PersonaExample>> retrieve(
    String context, {
    int limit = 2,
    String scopeKey = 'owner',
    String roleKey = 'role:personal',
  }) async {
    if (context.trim().isEmpty) return const [];
    final indexed = await _repository.searchExamples(
      context,
      limit: 40,
      scopeKey: scopeKey,
      roleKey: roleKey,
    );
    final normalizedContext = normalizePersonalLearningText(context);
    final terms = _meaningfulTerms(normalizedContext);

    var indexedBest = 0.0;
    for (final example in indexed) {
      final current = scoreExample(context, example);
      if (current > indexedBest) indexedBest = current;
    }
    final needsVariantFallback =
        terms.length <= 8 && (indexed.isEmpty || indexedBest < 0.75);
    final stored = needsVariantFallback
        ? await _repository.listExamples(limit: 200)
        : const <PersonaExample>[];
    final byId = <int, PersonaExample>{
      for (final example in indexed) example.id: example,
      for (final example in stored) example.id: example,
    };
    final candidates = byId.values.toList();

    // Un ejemplo pareado necesita superar el umbral de especificidad (0.45) para
    // que una coincidencia parcial en "hola" jamás desplace ni contamine un turno rico.
    const minPairedRelevance = 0.45;
    final scoresById = <int, double>{
      for (final c in candidates) c.id: scoreExample(context, c),
    };

    final eligible = candidates
        .where(
          (e) =>
              e.enabled &&
              (e.ownerVerified || e.isTemplate) &&
              (e.personaKey == scopeKey ||
                  e.personaKey == roleKey ||
                  e.personaKey == 'owner') &&
              (!e.isPaired || (scoresById[e.id] ?? 0.0) >= minPairedRelevance) &&
              !e.source.toLowerCase().contains('nano') &&
              e.source != 'assistant',
        )
        .toList();
    eligible.sort((a, b) {
      final relevance = (scoresById[b.id] ?? 0.0).compareTo(
        scoresById[a.id] ?? 0.0,
      );
      if (relevance != 0) return relevance;
      final scope = (b.personaKey == scopeKey ? 1 : 0).compareTo(
        a.personaKey == scopeKey ? 1 : 0,
      );
      if (scope != 0) return scope;
      if (a.isPaired != b.isPaired) return a.isPaired ? -1 : 1;
      return b.id.compareTo(a.id);
    });
    return eligible.take(limit.clamp(1, 4)).toList();
  }

  /// Conserva palabras cortas con valor conversacional sin permitir que
  /// artículos como "y" conviertan cualquier ejemplo en una coincidencia.
  static Set<String> _meaningfulTerms(String normalized) {
    const shortSignals = {'si', 'no', 'ok', 'ya', 'yo', 'tu', 'vos'};
    final terms = normalized
        .split(' ')
        .where((term) => term.length > 2 || shortSignals.contains(term))
        .toSet();
    if (terms.isEmpty && normalized.isNotEmpty) terms.add(normalized);
    return terms;
  }
}
