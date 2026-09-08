/// PERSONA-RETRIEVAL-07 — retriever de ejemplos de estilo.
///
/// Sin embeddings (V1): FTS4 puro en SQLite. El texto del mensaje entrante
/// es la query; los ejemplos más parecidos guían al modelo en el prompt.
/// La selección es determinista (MATCH FTS + recencia) — jamás un vector
/// generado ni una puntuación del LLM.
library;

import '../domain/persona_example.dart';
import 'persona_repository.dart';

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
    final candidates = await _repository.searchExamples(
      context,
      limit: 40,
      scopeKey: scopeKey,
      roleKey: roleKey,
    );
    final terms = context
        .toLowerCase()
        .split(RegExp(r'[^\p{L}\p{N}]+', unicode: true))
        .where((s) => s.length > 2)
        .toSet();
    int score(PersonaExample example) => example.incomingText
        .toLowerCase()
        .split(RegExp(r'[^\p{L}\p{N}]+', unicode: true))
        .where(terms.contains)
        .toSet()
        .length;
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
