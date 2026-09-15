import '../governance/action_confirmation.dart' show ActionConfirmation;
import 'action_path_router.dart' show ExecutionPath;
import 'tool_call.dart';
import 'tool_registry.dart' show PolicyVerdict;

/// Resultado tipado de la ejecución de herramientas: el veredicto
/// de la política y el feedback legible para el chat/trace. Si
/// [needsConfirmation], [pendingCall] guarda la llamada a re-ejecutar con
/// `confirmed: true` cuando el usuario apruebe.
enum ToolExecutionStatus {
  notExecuted,
  completed,
  completedUnverified,
  outcomeUnknown,
  failed,
}

class ToolOutcome {
  const ToolOutcome({
    required this.verdict,
    required this.feedback,
    this.pendingCall,
    this.executionStatus = ToolExecutionStatus.notExecuted,
  });

  final PolicyVerdict verdict;
  final String feedback;
  final ToolCall? pendingCall;
  final ToolExecutionStatus executionStatus;

  bool get needsConfirmation => verdict == PolicyVerdict.needsConfirmation;
  bool get executionFailed =>
      executionStatus == ToolExecutionStatus.failed ||
      executionStatus == ToolExecutionStatus.outcomeUnknown;
}

/// Presupuesto mutable perteneciente a una sola invocación/plan.
/// Nunca se almacena en el dispatcher compartido.
final class ToolExecutionBudget {
  int _stepsUsed = 0;

  int get stepsUsed => _stepsUsed;

  void recordExecution() => _stepsUsed++;
}

/// Resultado de ejecutar un plan multi-paso.
///
/// Distingue tres terminaciones: [completed] (todo verificado), [pauseIndex]
/// (un paso pidió confirmación humana — el plan queda en pausa y se reanuda
/// desde ahí con `confirmed: true`), o fallo tipado (política denegada o paso
/// no verificado → el plan se aborta).
class PlanOutcome {
  final bool completed;
  final List<ToolOutcome> steps;
  final int? pauseIndex;
  final ToolCall? pauseCall;
  final ActionConfirmation? confirmation;
  final String summary;

  /// Ruta de ejecución elegida por cada paso (paralelo a [steps]) — C6
  /// ActionPathRouter. Visible en UI como "Execution path".
  final List<ExecutionPath> paths;

  const PlanOutcome({
    required this.completed,
    required this.steps,
    this.pauseIndex,
    this.pauseCall,
    this.confirmation,
    required this.summary,
    this.paths = const [],
  });

  bool get hasUnverifiedSteps => steps.any(
    (step) => step.executionStatus == ToolExecutionStatus.completedUnverified,
  );
}
