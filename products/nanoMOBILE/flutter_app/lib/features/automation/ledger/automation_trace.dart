/// Traza de una ejecución de automatización — el registro honesto de lo que
/// se hizo (y de lo que se abortó/denegó).
///
/// Principio del plan maestro: la automatización NO es "el LLM respondió ok".
/// Cada intento queda trazado con su estado real, para auditoría, depuración y
/// el benchmark físico (C14: verificar ejecuciones REALES, no simuladas).
library;

import '../domain/automation_result.dart' show AutomationResultStatus;

/// Registro inmutable de una ejecución. Value object — no ejecuta nada.
class AutomationTrace {
  final String executionId;
  final String goal;

  /// Resultado final (vocabulario único del dominio).
  final AutomationResultStatus status;

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
