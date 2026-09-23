/// PERSONA-RETRIEVAL-07 — retriever de ejemplos de estilo.
///
/// Sin embeddings (V1): FTS4 puro en SQLite. El texto del mensaje entrante
/// es la query; los ejemplos más parecidos guían al modelo en el prompt.
/// La selección es determinista (MATCH FTS + recencia) — jamás un vector
/// generado ni una puntuación del LLM.
library;

import '../domain/persona_example.dart';
import 'persona_repository.dart';
import 'personal_learning_text.dart';

final class PersonaRetriever {
  PersonaRetriever({PersonaRepository? repository})
    : _repository = repository ?? PersonaRepository.instance;

  final PersonaRepository _repository;

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
    final terms = normalizePersonalLearningText(
      context,
    ).split(' ').where((s) => s.length > 2).toSet();
    int score(PersonaExample example) {
      var best = 0;
      for (final pattern in example.incomingVariants) {
        final matches = normalizePersonalLearningText(
          pattern,
        ).split(' ').where(terms.contains).toSet().length;
        if (matches > best) best = matches;
      }
      return best;
    }

    // FTS indexa la frase principal. Sólo los mensajes cortos sin una buena
    // coincidencia hacen el fallback acotado que incluye variantes; párrafos
    // grandes siguen por el índice/LLM y no escanean todo el catálogo.
    var indexedBest = 0;
    for (final example in indexed) {
      final current = score(example);
      if (current > indexedBest) indexedBest = current;
    }
    final needsVariantFallback =
        terms.length <= 8 && (indexed.isEmpty || indexedBest < terms.length);
    final stored = needsVariantFallback
        ? await _repository.listExamples(limit: 200)
        : const <PersonaExample>[];
    final byId = <int, PersonaExample>{
      for (final example in indexed) example.id: example,
      for (final example in stored) example.id: example,
    };
    final candidates = byId.values.toList();

    final eligible = candidates
        .where(
          (e) =>
              e.enabled &&
              (e.ownerVerified || e.isTemplate) &&
              (e.personaKey == scopeKey ||
                  e.personaKey == roleKey ||
                  e.personaKey == 'owner') &&
              !e.source.toLowerCase().contains('nano') &&
              e.source != 'assistant',
        )
        .toList();
    eligible.sort((a, b) {
      final scope = (b.personaKey == scopeKey ? 1 : 0).compareTo(
        a.personaKey == scopeKey ? 1 : 0,
      );
      if (scope != 0) return scope;
      final relevance = score(b).compareTo(score(a));
      if (relevance != 0) return relevance;
      if (a.isPaired != b.isPaired) return a.isPaired ? -1 : 1;
      return b.id.compareTo(a.id);
    });
    return eligible.take(limit.clamp(1, 4)).toList();
  }
}
