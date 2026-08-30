/// Snapshot coherente consumido por una decisión de Automation.
library;

import '../memory/object_memory.dart';
import '../notifications/notification_object.dart';
import '../perception/current_situation.dart';
import 'automation_run.dart';
import 'execution_journal.dart';
import 'task_plan.dart';

typedef AutomationMemorySource = NanoObjectMemory Function();

enum AutomationPerceptionStatus { notRequired, observed, unavailable }

/// Resultado factual de la captura de percepción para esta decisión.
final class AutomationPerceptionSnapshot {
  const AutomationPerceptionSnapshot._({
    required this.status,
    this.situation,
    this.reason,
  });

  const AutomationPerceptionSnapshot.notRequired()
    : this._(status: AutomationPerceptionStatus.notRequired);

  const AutomationPerceptionSnapshot.observed(CurrentSituation situation)
    : this._(status: AutomationPerceptionStatus.observed, situation: situation);

  const AutomationPerceptionSnapshot.unavailable(String reason)
    : this._(status: AutomationPerceptionStatus.unavailable, reason: reason);

  final AutomationPerceptionStatus status;
  final CurrentSituation? situation;
  final String? reason;

  bool get isObserved =>
      status == AutomationPerceptionStatus.observed && situation != null;
}

/// Estado de ejecución copiado desde el [AutomationRun] propietario.
final class AutomationExecutionSnapshot {
  const AutomationExecutionSnapshot({
    required this.executionId,
    required this.goal,
    required this.phase,
    required this.currentStep,
    required this.startedAt,
    required this.cancelled,
    required this.waitingConfirmation,
    this.journalStatus,
    this.journalStepId,
    this.actionSignature,
  });

  factory AutomationExecutionSnapshot.fromRun(
    AutomationRun run, {
    ExecutionJournalEntry? journalEntry,
  }) => AutomationExecutionSnapshot(
    executionId: run.executionId,
    goal: run.goal,
    phase: run.phase,
    currentStep: run.currentStep,
    startedAt: run.startedAt,
    cancelled: run.cancellation.isCancelled,
    waitingConfirmation: run.phase == AutomationRunPhase.waitingConfirmation,
    journalStatus: journalEntry?.status,
    journalStepId: journalEntry?.stepId,
    actionSignature: journalEntry?.actionSignature,
  );

  final String executionId;
  final String goal;
  final AutomationRunPhase phase;
  final int currentStep;
  final DateTime startedAt;
  final bool cancelled;
  final bool waitingConfirmation;
  final ExecutionJournalStatus? journalStatus;
  final String? journalStepId;
  final String? actionSignature;
}

/// Valores tipados producidos por pasos anteriores. Es una copia inmutable,
/// no la tabla mutable usada internamente por el orquestador.
final class AutomationWorldSnapshot {
  AutomationWorldSnapshot(
    Map<TaskValueId, TaskValue> values, {
    Iterable<NotificationObject> notifications = const [],
    this.notificationFailure,
  }) : values = Map.unmodifiable(values),
       notifications = List.unmodifiable(notifications);

  final Map<TaskValueId, TaskValue> values;
  final List<NotificationObject> notifications;
  final String? notificationFailure;

  TaskValue? valueOf(TaskValueId id) => values[id];
}

/// Interpretación determinista del objetivo vigente para esta decisión.
final class AutomationConversationSnapshot {
  const AutomationConversationSnapshot({
    this.appName = '',
    this.target = '',
    this.draft = '',
    this.query = '',
    this.resultOrdinal,
    this.resultText = '',
  });

  final String appName;
  final String target;
  final String draft;
  final String query;
  final int? resultOrdinal;
  final String resultText;
}

/// Vista acotada de la memoria UI copy-on-write disponible al capturar.
/// No mezcla memoria conversacional, journal ni experiencia verificada.
final class RelevantAutomationMemory {
  const RelevantAutomationMemory({
    required this.objectMemory,
    required this.targetConcept,
    required this.packageName,
  });

  final NanoObjectMemory objectMemory;
  final String targetConcept;
  final String packageName;
}

/// Value context de una única decisión.
///
/// No es singleton, no se actualiza después de crearse y no concede autoridad.
/// Una nueva observación o un cambio de ejecución exige construir otro contexto.
final class AutomationContext {
  AutomationContext({
    required String goal,
    required String decisionStepId,
    required this.execution,
    required this.world,
    required this.perception,
    required this.conversation,
    required this.relevantMemory,
    required Map<String, RequiredEvidence> evidence,
    required DateTime capturedAt,
  }) : goal = goal.trim(),
       decisionStepId = decisionStepId.trim(),
       evidence = Map.unmodifiable(evidence),
       capturedAt = capturedAt.toUtc() {
    if (this.goal.isEmpty) {
      throw ArgumentError.value(goal, 'goal', 'el contexto requiere objetivo');
    }
    if (execution.executionId.isEmpty) {
      throw ArgumentError('el contexto requiere executionId');
    }
    if (this.decisionStepId.isEmpty) {
      throw ArgumentError('el contexto requiere stepId');
    }
    if (execution.goal != this.goal) {
      throw ArgumentError(
        'el objetivo del contexto no pertenece al AutomationRun capturado',
      );
    }
    final journalStepId = execution.journalStepId;
    if (journalStepId != null && journalStepId != this.decisionStepId) {
      throw ArgumentError(
        'el journal y la decisión pertenecen a pasos distintos',
      );
    }
    final observedAt = perception.situation?.observedAt;
    if (observedAt != null && observedAt.isAfter(this.capturedAt)) {
      throw ArgumentError(
        'la percepción no puede ser posterior a la captura del contexto',
      );
    }
    final memoryPackage = relevantMemory?.packageName ?? '';
    final observedPackage = perception.situation?.packageName ?? '';
    if (memoryPackage.isNotEmpty &&
        observedPackage.isNotEmpty &&
        memoryPackage != observedPackage) {
      throw ArgumentError(
        'la memoria relevante y la percepción pertenecen a paquetes distintos',
      );
    }
  }

  final String goal;
  final String decisionStepId;
  final AutomationExecutionSnapshot execution;
  final AutomationWorldSnapshot world;
  final AutomationPerceptionSnapshot perception;
  final AutomationConversationSnapshot conversation;
  final RelevantAutomationMemory? relevantMemory;
  final Map<String, RequiredEvidence> evidence;
  final DateTime capturedAt;

  /// Produce un nuevo value context cuando el journal cambia antes de ejecutar,
  /// conservando exactamente el world/perception snapshot ya capturado.
  AutomationContext withExecution(
    AutomationExecutionSnapshot nextExecution, {
    required DateTime capturedAt,
  }) => AutomationContext(
    goal: goal,
    decisionStepId: decisionStepId,
    execution: nextExecution,
    world: world,
    perception: perception,
    conversation: conversation,
    relevantMemory: relevantMemory,
    evidence: evidence,
    capturedAt: capturedAt,
  );
}
