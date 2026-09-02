/// CandidateSet (A5) — colección inmutable de candidatos sin IDs duplicados.
///
/// Solo semántica de colección: listar, lookup por [CandidateId], estado vacío.
/// SIN ranking (A6) y SIN ejecución.
library;

import 'candidate_action.dart';

final class CandidateSet {
  CandidateSet(List<CandidateAction> candidates)
    : _items = List.unmodifiable(candidates),
      _byId = _buildIndex(candidates);

  final List<CandidateAction> _items;
  final Map<CandidateId, CandidateAction> _byId;

  static Map<CandidateId, CandidateAction> _buildIndex(
    List<CandidateAction> candidates,
  ) {
    final index = <CandidateId, CandidateAction>{};
    for (final c in candidates) {
      if (index.containsKey(c.id)) {
        throw ArgumentError('CandidateId duplicado: ${c.id}');
      }
      index[c.id] = c;
    }
    return Map.unmodifiable(index);
  }

  List<CandidateAction> get items => _items;
  int get length => _items.length;
  bool get isEmpty => _items.isEmpty;
  CandidateAction? byId(CandidateId id) => _byId[id];
}
