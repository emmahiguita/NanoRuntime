/// CandidateSelectionEngine (A6.5) — orquesta ranker determinista + selector
/// de ambigüedad. Filosofía Nano: MÍNIMO de inteligencia necesaria.
///
/// - SelectedCandidate / NoCandidate → se devuelve directo, 0 LLM.
/// - AmbiguousCandidates → se invoca el selector (Koog) SOLO si existe.
/// - Sin selector → se preserva la ambigüedad.
library;

import 'candidate_ranker.dart';
import 'candidate_selection.dart';
import 'candidate_selector.dart';
import 'candidate_set.dart';

class CandidateSelectionEngine {
  CandidateSelectionEngine({
    required CandidateRanker ranker,
    CandidateSelector? koogSelector,
  }) : _ranker = ranker,
       _koog = koogSelector;

  final CandidateRanker _ranker;
  final CandidateSelector? _koog;

  Future<CandidateSelection> select(CandidateSelectionRequest request) async {
    final ranked = _ranker.rank(request.candidates);
    if (ranked is! AmbiguousCandidates) return ranked; // Selected/NoCandidate

    final koog = _koog;
    if (koog == null) return ranked; // sin selector → preservar ambigüedad

    // Solo los candidatos ambiguos van al selector (nunca el set completo).
    final ambiguousSet = CandidateSet(ranked.candidates);
    return koog.select(
      CandidateSelectionRequest(goal: request.goal, candidates: ambiguousSet),
    );
  }
}
