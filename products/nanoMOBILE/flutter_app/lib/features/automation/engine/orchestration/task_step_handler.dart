/// TaskStepHandler — estrategia de un paso semántico (SRP/OCP).
///
/// Cada paso es una clase pequeña. Añadir un paso = añadir un handler (OCP), no
/// tocar el switch del orquestador. El orquestador itera `allStepHandlers()`.
library;

import 'goal_context.dart';
import 'step_environment.dart';
import 'task_plan.dart';

/// Contexto de ejecución de un paso: el paso, los valores intermedios tipados,
/// la intención parseada y las fuentes inyectadas.
class StepContext {
  final TaskStep step;
  final Map<TaskValueId, TaskValue> values;
  final GoalContext goal;
  final StepEnvironment env;

  const StepContext({
    required this.step,
    required this.values,
    required this.goal,
    required this.env,
  });
}

abstract interface class TaskStepHandler {
  String get semanticAction;

  Future<TaskStepResult> handle(StepContext ctx);
}
