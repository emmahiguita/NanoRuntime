/// CandidateSelector (A6.5) — puerto de selección asistida de candidatos.
///
/// El selector SOLO resuelve ambigüedad sobre candidatos YA existentes. No crea
/// CandidateAction ni ToolCall. El CandidateSet es la autoridad: el selector
/// referencia un [CandidateId] existente o se abstiene.
library;

import 'candidate_selection.dart';
import 'candidate_set.dart';

/// Solicitud mínima de selección: goal + candidatos (subconjunto ambiguo).
/// No es un AgentContext gigante.
class CandidateSelectionRequest {
  final String goal;
  final CandidateSet candidates;

  const CandidateSelectionRequest({
    required this.goal,
    required this.candidates,
  });
}

abstract interface class CandidateSelector {
  Future<CandidateSelection> select(CandidateSelectionRequest request);
}
