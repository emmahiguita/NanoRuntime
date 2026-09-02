/// CandidateSelection (A5) — resultado honesto de una selección.
///
/// A5 define la semántica; A6 implementará el ranking que produce estos
/// resultados. No se elige el top automáticamente aquí.
library;

import 'candidate_action.dart';

sealed class CandidateSelection {
  const CandidateSelection();
}

/// Un único candidato seleccionado.
final class SelectedCandidate extends CandidateSelection {
  final CandidateAction candidate;
  const SelectedCandidate(this.candidate);
}

/// Varios candidatos igualmente plausibles: NO auto-seleccionar.
final class AmbiguousCandidates extends CandidateSelection {
  final List<CandidateAction> candidates;
  final String reason;

  AmbiguousCandidates(List<CandidateAction> candidates, this.reason)
    : candidates = List.unmodifiable(candidates);
}

/// Sin candidato viable.
final class NoCandidate extends CandidateSelection {
  final String reason;
  const NoCandidate(this.reason);
}

/// El selector (p. ej. Koog) produjo un candidateId que NO existe en el set,
/// o una salida no interpretable. La selección se rechaza; el CandidateSet
/// sigue siendo la autoridad (nunca se crea una acción nueva desde el modelo).
final class InvalidCandidateSelection extends CandidateSelection {
  final String reason;
  const InvalidCandidateSelection(this.reason);
}
