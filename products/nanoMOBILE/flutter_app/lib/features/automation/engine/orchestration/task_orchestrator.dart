/// A15.0 — TaskOrchestrator: ejecuta un TaskPlan paso a paso, transportando
/// TaskValues TIPADOS entre dominios.
///
/// NO es un workflow engine libre. Despacha a TaskStepHandler (estrategia):
/// añadir un paso = añadir un handler (OCP), sin tocar el switch. La lógica de
/// cada paso vive en su handler; aquí solo orquestación + recuperación acotada.
library;

import '../voice/execution_cancellation.dart';
import 'goal_context.dart';
import 'handlers/app_step_handlers.dart';
import 'handlers/data_step_handlers.dart';
import 'handlers/messaging_step_handlers.dart';
import 'handlers/search_step_handlers.dart';
import 'step_environment.dart';
import 'task_plan.dart';
import 'task_step_handler.dart';

/// Handlers por defecto (composición). Inyectables para tests/añadir pasos.
const List<TaskStepHandler> defaultStepHandlers = [
  ReadNotificationHandler(),
  ExtractUrlHandler(),
  WriteFileHandler(),
  OpenUrlHandler(),
  OpenAppHandler(),
  OpenConversationHandler(),
  WriteMessageHandler(),
  SendMessageHandler(),
  WriteQueryHandler(),
  SubmitSearchHandler(),
  SelectResultHandler(),
];

class TaskOrchestrator {
  TaskOrchestrator({
    required StepEnvironment env,
    List<TaskStepHandler>? handlers,
    this.maxAttemptsPerStep = 2,
    this.maxReplansPerTask = 2,
  }) : _env = env,
       _handlers = {
         for (final h in handlers ?? defaultStepHandlers) h.semanticAction: h,
       };

  final StepEnvironment _env;
  final Map<String, TaskStepHandler> _handlers;
  final GoalContextParser _parser = const GoalContextParser();

  /// A15.1 — presupuesto de recuperación acotado.
  final int maxAttemptsPerStep;
  final int maxReplansPerTask;

  /// Ejecuta el plan en orden topológico con recuperación ACOTADA (A15.1).
  Future<List<TaskStepResult>> run(
    TaskPlan plan, {
    ExecutionCancellationToken? cancel,
  }) async {
    final invalid = plan.validate();
    if (invalid != null) {
      return [TaskStepResult(status: TaskStepStatus.failed, reason: invalid)];
    }

    final values = <TaskValueId, TaskValue>{};
    final results = <TaskStepResult>[];
    var replans = 0;
    final goal = _parser.parse(plan.goal);

    for (final step in plan.ordered) {
      // A16 — cancelación cooperativa: aborta ANTES del siguiente paso.
      try {
        cancel?.throwIfCancelled();
      } on ExecutionCancelled {
        results.add(
          const TaskStepResult(
            status: TaskStepStatus.failed,
            reason: 'cancelado por el usuario',
            failureKind: TaskFailureKind.terminal,
          ),
        );
        break;
      }

      var result = await _runStep(step, values, goal);
      var attempts = 1;

      while (!result.isCompleted &&
          result.isRecoverable &&
          attempts < maxAttemptsPerStep &&
          replans < maxReplansPerTask) {
        replans++;
        attempts++;
        final next = await _runStep(step, values, goal);
        // Detección de loop: mismo motivo sin progreso → detener.
        if (next.reason == result.reason && !next.isCompleted) {
          result = next;
          break;
        }
        result = next;
      }

      results.add(result);
      if (!result.isCompleted) break;
      if (step.produces != null && result.output != null) {
        values[step.produces!] = result.output!;
      }
    }
    return results;
  }

  Future<TaskStepResult> _runStep(
    TaskStep step,
    Map<TaskValueId, TaskValue> values,
    GoalContext goal,
  ) async {
    final handler = _handlers[step.semanticAction];
    if (handler == null) {
      return const TaskStepResult(
        status: TaskStepStatus.needsMoreEvidence,
        reason: 'semántica desconocida',
      );
    }
    return handler.handle(
      StepContext(step: step, values: values, goal: goal, env: _env),
    );
  }
}
