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

  /// Target de continuación (A14.8): identidad grounded que viene de la capa de
  /// notificación (sender/conversation), NO del texto del modelo. Ej. "Juan".
  /// Vacío/null = no hay contexto de continuación; el provider lo deriva del goal.
  final String? continuationTarget;

  /// Borrador de mensaje aprobado (A14.8): texto proveniente de intención del
  /// usuario o respuesta generada aprobada, NO de instrucciones de pantalla.
  /// El write candidate lo usa como payload y como postcondición TextFieldContains.
  final String? draftText;

  const CandidateRequest(this.goal, {this.continuationTarget, this.draftText});
}

/// Genera opciones grounded para un [CandidateRequest]. Cada provider es una
/// fuente con su propia proveniencia de evidencia.
abstract interface class CandidateProvider {
  String get id;

  Future<List<CandidateAction>> provide(CandidateRequest request);
}
