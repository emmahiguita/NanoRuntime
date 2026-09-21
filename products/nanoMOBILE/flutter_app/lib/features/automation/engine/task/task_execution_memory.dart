/// Estado del ciclo de vida de una tarea multietapa en memoria operativa.
enum TaskExecutionPhase {
  created,
  observing,
  acting,
  verifying,
  suspended,
  completed,
  failed,
}

/// Registro inmutable de un paso completado con su evidencia.
class CompletedTaskStep {
  final String stepName;
  final String targetApp;
  final String actionTaken;
  final String evidence;
  final DateTime timestamp;

  const CompletedTaskStep({
    required this.stepName,
    required this.targetApp,
    required this.actionTaken,
    required this.evidence,
    required this.timestamp,
  });
}

/// Snapshot del estado actual de una tarea multietapa de automatización.
class TaskExecutionSnapshot {
  final String taskId;
  final String goal;
  final String currentApp;
  final String? currentWindow;
  final TaskExecutionPhase phase;
  final String? expectedOutcome;
  final List<CompletedTaskStep> completedSteps;
  final List<String> pendingSteps;
  final DateTime startedAt;
  final DateTime lastUpdatedAt;

  const TaskExecutionSnapshot({
    required this.taskId,
    required this.goal,
    required this.currentApp,
    this.currentWindow,
    required this.phase,
    this.expectedOutcome,
    this.completedSteps = const [],
    this.pendingSteps = const [],
    required this.startedAt,
    required this.lastUpdatedAt,
  });
}

/// Almacén en memoria de la ejecución operativa de Nano AI.
///
/// Principios SOLID:
/// - SRP: Responsabilidad exclusiva de retener y recuperar el progreso de tareas activas.
/// - Resiliencia: Permite restaurar tareas tras suspensiones de Android o cambios de app.
class TaskExecutionMemoryStore {
  TaskExecutionSnapshot? _activeTask;

  TaskExecutionSnapshot? get activeTask => _activeTask;
  bool get hasActiveTask => _activeTask != null;

  /// Inicia el seguimiento de una nueva tarea multietapa.
  void startTask({
    required String taskId,
    required String goal,
    required String initialApp,
    List<String> plannedSteps = const [],
    String? expectedOutcome,
  }) {
    final now = DateTime.now().toUtc();
    _activeTask = TaskExecutionSnapshot(
      taskId: taskId,
      goal: goal,
      currentApp: initialApp,
      phase: TaskExecutionPhase.created,
      expectedOutcome: expectedOutcome,
      pendingSteps: List.unmodifiable(plannedSteps),
      startedAt: now,
      lastUpdatedAt: now,
    );
  }

  /// Actualiza la fase y la aplicación actualmente en foco.
  void updatePhase({
    required TaskExecutionPhase phase,
    String? currentApp,
    String? currentWindow,
  }) {
    final current = _activeTask;
    if (current == null) return;
    _activeTask = TaskExecutionSnapshot(
      taskId: current.taskId,
      goal: current.goal,
      currentApp: currentApp ?? current.currentApp,
      currentWindow: currentWindow ?? current.currentWindow,
      phase: phase,
      expectedOutcome: current.expectedOutcome,
      completedSteps: current.completedSteps,
      pendingSteps: current.pendingSteps,
      startedAt: current.startedAt,
      lastUpdatedAt: DateTime.now().toUtc(),
    );
  }

  /// Registra un paso completado y verificado, removiéndolo de pendientes.
  void recordStepCompleted({
    required String stepName,
    required String targetApp,
    required String actionTaken,
    required String evidence,
  }) {
    final current = _activeTask;
    if (current == null) return;

    final step = CompletedTaskStep(
      stepName: stepName,
      targetApp: targetApp,
      actionTaken: actionTaken,
      evidence: evidence,
      timestamp: DateTime.now().toUtc(),
    );

    final updatedCompleted = [...current.completedSteps, step];
    final updatedPending = current.pendingSteps.where((s) => s != stepName).toList();

    _activeTask = TaskExecutionSnapshot(
      taskId: current.taskId,
      goal: current.goal,
      currentApp: targetApp,
      currentWindow: current.currentWindow,
      phase: TaskExecutionPhase.acting,
      expectedOutcome: current.expectedOutcome,
      completedSteps: List.unmodifiable(updatedCompleted),
      pendingSteps: List.unmodifiable(updatedPending),
      startedAt: current.startedAt,
      lastUpdatedAt: DateTime.now().toUtc(),
    );
  }

  /// Suspende temporalmente la tarea (por cambio de ventana o espera de usuario).
  void suspendTask({String? reason}) {
    updatePhase(phase: TaskExecutionPhase.suspended);
  }

  /// Finaliza la tarea actual y libera el contexto operativo.
  void completeTask({bool success = true}) {
    updatePhase(
      phase: success ? TaskExecutionPhase.completed : TaskExecutionPhase.failed,
    );
  }

  /// Limpia la memoria operativa una vez archivada.
  void clear() {
    _activeTask = null;
  }
}
