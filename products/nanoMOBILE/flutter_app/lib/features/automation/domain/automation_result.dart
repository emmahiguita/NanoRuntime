/// Resultado honesto de una ejecución de automatización — contrato de dominio.
///
/// Vocabulario ÚNICO de estado del módulo (lo usa el ledger, el coordinator y
/// la UI). Nunca inventa éxito; todo estado es un veredicto real.
library;

/// Estado honesto de una ejecución.
enum AutomationResultStatus {
  /// Objetivo satisfecho contra el estado real.
  completed,

  /// Plan completo y verificado paso a paso, pero sin expectativa de objetivo
  /// declarada (no se declara cumplimiento).
  completedUnverified,

  /// Un paso pidió confirmación humana; el flujo sigue vivo y puede reanudar.
  paused,

  /// La política denegó un tool del plan.
  denied,

  /// Sin flujo verificado en cache ni planner disponible.
  noPlan,

  /// El plan no completó o el objetivo resultó no satisfecho.
  failed,

  /// Cancelación cooperativa solicitada.
  cancelled,
}

/// Resultado normalizado de [AutomationCoordinator.execute].
class AutomationResult {
  final String executionId;
  final AutomationResultStatus status;
  final String reason;

  /// Índice del paso donde el plan se pausó por confirmación (solo [paused]).
  final int? pauseIndex;

  /// Tool que pidió confirmación (solo [paused]).
  final String? pauseTool;

  const AutomationResult({
    required this.executionId,
    required this.status,
    required this.reason,
    this.pauseIndex,
    this.pauseTool,
  });

  bool get isPaused => status == AutomationResultStatus.paused;
}
