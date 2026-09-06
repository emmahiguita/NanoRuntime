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
  Future<List<PersonaExample>> retrieve(String context, {int limit = 2}) {
    if (context.trim().isEmpty) return Future.value(const []);
    return _repository.searchExamples(context, limit: limit);
  }
}
