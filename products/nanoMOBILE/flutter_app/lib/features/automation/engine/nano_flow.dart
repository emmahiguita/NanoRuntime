/// NanoFlow (Fase C8) — ejecución DETERMINISTA de un flujo verificado.
///
/// Principio del plan maestro: "el LLM NO debe hacer el trabajo que puede
/// hacer un flujo determinista. El LLM planea; las herramientas ejecutan;
/// los verifiers demuestran." Cuando el [ExperienceCache] (C7) ya tiene un
/// flow verificado para el objetivo, [NanoFlowExecutor] lo ejecuta SIN
/// razonamiento LLM paso a paso: cada paso pasa por la misma gobernanza
/// (política + AgentLoop + verificación) que el plan del LLM.
///
/// Koog/intervención LLM solo se necesita si el flow falla o el estado
/// sorprende al ejecutor.
library;

import 'agent_tool_dispatcher.dart';
import 'goal_verifier.dart';

/// Flujo determinista: objetivo + pasos verificados + expectativa final.
class NanoFlow {
  final String goal;

  /// Plan que completó verificado (de [ExperienceCache]).
  final List<ToolCall> steps;

  /// Expectativa del objetivo para la comprobación final (C3).
  final GoalExpectation? goalExpectation;

  const NanoFlow({
    required this.goal,
    required this.steps,
    this.goalExpectation,
  });
}

class FlowExecutionResult {
  /// True si el flujo completo ejecutó + verificó + el objetivo se cumplió
  /// (o quedó [GoalStatus.unverified] con plan completo — honesto).
  final bool completed;

  final PlanOutcome plan;
  final GoalVerification goal;

  const FlowExecutionResult({
    required this.completed,
    required this.plan,
    required this.goal,
  });
}

/// Ejecuta [NanoFlow]s. DIP: depende de [AgentToolDispatcher] (gobernanza +
/// loop + verificación por paso) y [GoalVerifier] (comprobación final).
class NanoFlowExecutor {
  NanoFlowExecutor({
    required AgentToolDispatcher dispatcher,
    required GoalVerifier goalVerifier,
  })  : _dispatcher = dispatcher,
        _goalVerifier = goalVerifier;

  final AgentToolDispatcher _dispatcher;
  final GoalVerifier _goalVerifier;

  /// Ejecuta el flujo. Sin `confirmed`, el primer paso sensible pausa
  /// ([plan.pauseIndex] != null) — el caller muestra la confirmación y
  /// re-llama con `confirmed: true` (el flujo completo queda autorizado).
  Future<FlowExecutionResult> execute(
    NanoFlow flow, {
    bool confirmed = false,
  }) async {
    final plan = await _dispatcher.runPlanGuarded(
      flow.steps,
      confirmed: confirmed,
    );
    if (plan.pauseIndex != null) {
      // Pausa: sin plan completo no hay verificación de objetivo todavía.
      return FlowExecutionResult(
        completed: false,
        plan: plan,
        goal: const GoalVerification(
          GoalStatus.unverified,
          'Flujo en pausa por confirmación: sin verificación de objetivo.',
        ),
      );
    }

    final goal = await _goalVerifier.verify(
      flow.goal,
      planCompleted: plan.completed,
      expectation: flow.goalExpectation,
    );
    return FlowExecutionResult(
      // El flujo completó si el plan terminó verificado Y el objetivo NO
      // quedó explícitamente no cumplido (unverified = plan completo sin
      // expectativa declarada — estado honesto, cuenta como completado).
      completed: plan.completed && goal.status != GoalStatus.notSatisfied,
      plan: plan,
      goal: goal,
    );
  }
}
