/// CandidateProvider (A5) — puerto de extensión de fuentes de candidatos.
///
/// A5 define SOLO la interfaz. A6 implementará los providers concretos
/// (DeterministicCandidateProvider, InstalledAppCandidateProvider,
/// SystemIntentCandidateProvider, NanoFlowCandidateProvider, etc.). No crear
/// placeholders vacíos de cada provider futuro (no "architecture theatre").
library;

import 'candidate_action.dart';

/// Solicitud mínima de candidatos (A5). A6 la extenderá con SystemGraph,
/// catálogo y contexto de planificación, evitando un CandidateContext gigante
/// prematuro.
class CandidateRequest {
  final String goal;
  const CandidateRequest(this.goal);
}

/// Genera opciones grounded para un [CandidateRequest]. Cada provider es una
/// fuente con su propia proveniencia de evidencia.
abstract interface class CandidateProvider {
  String get id;

  Future<List<CandidateAction>> provide(CandidateRequest request);
}
