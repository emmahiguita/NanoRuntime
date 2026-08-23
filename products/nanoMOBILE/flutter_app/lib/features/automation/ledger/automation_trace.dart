/// Traza de una ejecución de automatización — el registro honesto de lo que
/// se hizo (y de lo que se abortó/denegó).
///
/// Principio del plan maestro: la automatización NO es "el LLM respondió ok".
/// Cada intento queda trazado con su estado real, para auditoría, depuración y
/// el benchmark físico (C14: verificar ejecuciones REALES, no simuladas).
library;

/// Estado final honesto de una ejecución. Nunca inventa éxito:
/// - [completed]: plan verificado y objetivo satisfecho.
/// - [completedUnverified]: plan completo paso a paso, sin expectativa de
///   objetivo declarada (no se declara cumplimiento).
/// - [paused]: un paso pidió confirmación humana (el flujo sigue vivo).
/// - [denied]: la política denegó un tool del plan.
/// - [noPlan]: sin flujo verificado en cache ni planner disponible.
/// - [failed]: el plan no completó o el objetivo resultó No satisfecho.
/// - [cancelled]: cancelación cooperativa solicitada.
enum AutomationTraceStatus {
  completed,
  completedUnverified,
  paused,
  denied,
  noPlan,
  failed,
  cancelled,
}

/// Registro inmutable de una ejecución. Value object — no ejecuta nada.
class AutomationTrace {
  final String executionId;
  final String goal;

  /// Resultado final.
  final AutomationTraceStatus status;

  /// Resumen legible (qué pasó, en español).
  final String summary;

  /// Índice donde el plan quedó en pausa por confirmación (solo [paused]).
  final int? pauseIndex;

  /// Tool que pidió confirmación (solo [paused]).
  final String? pauseTool;

  final DateTime startedAt;
  final DateTime endedAt;

  const AutomationTrace({
    required this.executionId,
    required this.goal,
    required this.status,
    required this.summary,
    this.pauseIndex,
    this.pauseTool,
    required this.startedAt,
    required this.endedAt,
  });

  Duration get duration => endedAt.difference(startedAt);

  @override
  String toString() =>
      '[trace] $executionId $goal → $status (${duration.inMilliseconds}ms)';
}
