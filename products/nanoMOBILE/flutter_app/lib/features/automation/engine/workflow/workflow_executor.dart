/// WorkflowExecutor — coordinador desacoplado de flujos multi-paso.
///
/// Principios arquitectónicos (SOLID):
/// - SRP: solo orquesta la secuencia de pasos, delegando la selección al planner,
///   la ejecución al dispatcher, la reactividad al waiter y la verificación al verifier.
/// - DIP: depende de contratos abstractos e inyectables.
/// - Delimitación del SO: reconoce superficies protegidas (FLAG_SECURE) y
///   delega formalmente al usuario (require user interaction) en lugar de fallar a ciegas.
library;

import '../execution/action_verifier.dart';
import '../execution/agent_tool_dispatcher.dart';
import '../execution/event_driven_waiter.dart';
import '../execution/goal_verifier.dart';
import '../system/app_capability_registry.dart';

/// Estado de ejecución de un workflow multi-paso.
enum WorkflowStatus {
  inProgress,
  completed,
  failed,
  secureSurfaceDetected,
  needsConfirmation,
  aborted,
}

/// Definición de un paso dentro de un workflow.
class WorkflowStep {
  final String id;
  final String description;
  final ToolCall toolCall;
  final String? targetPackage;
  final ActionExpectation? expectation;
  final bool requiresForeground;

  const WorkflowStep({
    required this.id,
    required this.description,
    required this.toolCall,
    this.targetPackage,
    this.expectation,
    this.requiresForeground = true,
  });
}

/// Objetivo o misión multi-paso para el orquestador.
class WorkflowGoal {
  final String id;
  final String title;
  final String? targetPackage;
  final List<WorkflowStep> steps;
  final GoalExpectation? finalExpectation;

  const WorkflowGoal({
    required this.id,
    required this.title,
    this.targetPackage,
    required this.steps,
    this.finalExpectation,
  });
}

/// Resultado de la ejecución de un paso individual.
class WorkflowStepResult {
  final WorkflowStep step;
  final ToolOutcome outcome;
  final EventWaitResult? eventWait;
  final bool verified;
  final String summary;

  const WorkflowStepResult({
    required this.step,
    required this.outcome,
    this.eventWait,
    required this.verified,
    required this.summary,
  });

  bool get isSuccess =>
      !outcome.executionFailed &&
      !outcome.needsConfirmation &&
      verified;
}

/// Informe final estructurado de la ejecución de un workflow.
class WorkflowReport {
  final String goalId;
  final String title;
  final WorkflowStatus status;
  final List<WorkflowStepResult> stepsExecuted;
  final Duration elapsed;
  final String summary;

  const WorkflowReport({
    required this.goalId,
    required this.title,
    required this.status,
    required this.stepsExecuted,
    required this.elapsed,
    required this.summary,
  });

  bool get isCompleted => status == WorkflowStatus.completed;
  bool get isSecureSurface => status == WorkflowStatus.secureSurfaceDetected;
}

/// Coordinador multi-paso desacoplado con soporte de eventos reactivos
/// y enrutamiento de fallbacks.
class WorkflowExecutor {
  WorkflowExecutor({
    required AgentToolDispatcher dispatcher,
    required EventDrivenWaiter waiter,
    AppCapabilityRegistry? capabilityRegistry,
    ActionVerifier? verifier,
    GoalVerifier? goalVerifier,
  })  : _dispatcher = dispatcher,
        _waiter = waiter,
        _capabilityRegistry = capabilityRegistry ?? AppCapabilityRegistry(),
        _verifier = verifier,
        _goalVerifier = goalVerifier;

  final AgentToolDispatcher _dispatcher;
  final EventDrivenWaiter _waiter;
  final AppCapabilityRegistry _capabilityRegistry;
  final ActionVerifier? _verifier;
  final GoalVerifier? _goalVerifier;

  /// Ejecuta el flujo multi-paso [goal] paso a paso con espera reactiva y verificación.
  Future<WorkflowReport> executeWorkflow(
    WorkflowGoal goal, {
    ToolExecutionBudget? budget,
  }) async {
    final stopwatch = Stopwatch()..start();
    final executed = <WorkflowStepResult>[];
    final activeBudget = budget ?? ToolExecutionBudget();

    for (var i = 0; i < goal.steps.length; i++) {
      final step = goal.steps[i];

      // 1. Ejecución del ToolCall a través de gobernanza y dispatcher
      final outcome = await _dispatcher.runToolGuarded(
        step.toolCall,
        budget: activeBudget,
      );

      // Si requiere confirmación humana (acción destructiva o sensible)
      if (outcome.needsConfirmation) {
        executed.add(
          WorkflowStepResult(
            step: step,
            outcome: outcome,
            verified: false,
            summary: 'Pausa por confirmación de seguridad requerida.',
          ),
        );
        stopwatch.stop();
        return WorkflowReport(
          goalId: goal.id,
          title: goal.title,
          status: WorkflowStatus.needsConfirmation,
          stepsExecuted: executed,
          elapsed: stopwatch.elapsed,
          summary: 'El paso ${i + 1} (${step.description}) requiere confirmación humana.',
        );
      }

      // Comprobación de errores de superficie protegida (FLAG_SECURE)
      if (outcome.feedback.contains('SECURE_SURFACE') ||
          outcome.feedback.contains('Superficie segura')) {
        executed.add(
          WorkflowStepResult(
            step: step,
            outcome: outcome,
            verified: false,
            summary: 'Superficie protegida por FLAG_SECURE.',
          ),
        );
        stopwatch.stop();
        return WorkflowReport(
          goalId: goal.id,
          title: goal.title,
          status: WorkflowStatus.secureSurfaceDetected,
          stepsExecuted: executed,
          elapsed: stopwatch.elapsed,
          summary:
              'Superficie segura detectada en el paso ${i + 1}. Por seguridad del sistema, la automatización requiere intervención manual del usuario.',
        );
      }

      if (outcome.executionFailed) {
        executed.add(
          WorkflowStepResult(
            step: step,
            outcome: outcome,
            verified: false,
            summary: 'Fallo de ejecución: ${outcome.feedback}',
          ),
        );
        stopwatch.stop();
        return WorkflowReport(
          goalId: goal.id,
          title: goal.title,
          status: WorkflowStatus.failed,
          stepsExecuted: executed,
          elapsed: stopwatch.elapsed,
          summary: 'Fallo en paso ${i + 1} (${step.description}): ${outcome.feedback}',
        );
      }

      // 2. Espera reactiva por eventos de accesibilidad del sistema
      EventWaitResult? waitResult;
      if (step.requiresForeground) {
        if (step.targetPackage != null && step.targetPackage!.isNotEmpty) {
          waitResult = await _waiter.waitForPackage(
            step.targetPackage!,
            timeout: const Duration(milliseconds: 2000),
          );
        } else {
          waitResult = await _waiter.waitForTransition(
            timeout: const Duration(milliseconds: 1200),
          );
        }
      }

      // 3. Verificación de postcondición
      var stepVerified = true;
      String stepSummary = outcome.feedback;

      if (step.expectation != null && _verifier != null) {
        final v = await _verifier.verify(step.expectation!);
        stepVerified = v.isVerified;
        if (!stepVerified) {
          stepSummary = 'Postcondición no cumplida: ${v.reason}';
        }
      }

      executed.add(
        WorkflowStepResult(
          step: step,
          outcome: outcome,
          eventWait: waitResult,
          verified: stepVerified,
          summary: stepSummary,
        ),
      );

      if (!stepVerified) {
        stopwatch.stop();
        return WorkflowReport(
          goalId: goal.id,
          title: goal.title,
          status: WorkflowStatus.failed,
          stepsExecuted: executed,
          elapsed: stopwatch.elapsed,
          summary:
              'Paso ${i + 1} (${step.description}) ejecutado pero la verificación de postcondición no se cumplió.',
        );
      }
    }

    // 4. Verificación global del objetivo final (si se declaró)
    if (goal.finalExpectation != null && _goalVerifier != null) {
      final finalCheck = await _goalVerifier.verify(
        goal.title,
        planCompleted: true,
        expectation: goal.finalExpectation,
      );
      if (finalCheck.status != GoalStatus.satisfied) {
        stopwatch.stop();
        return WorkflowReport(
          goalId: goal.id,
          title: goal.title,
          status: WorkflowStatus.failed,
          stepsExecuted: executed,
          elapsed: stopwatch.elapsed,
          summary: 'Los pasos se ejecutaron pero el objetivo final no se satisfizo: ${finalCheck.reason}',
        );
      }
    }

    stopwatch.stop();
    return WorkflowReport(
      goalId: goal.id,
      title: goal.title,
      status: WorkflowStatus.completed,
      stepsExecuted: executed,
      elapsed: stopwatch.elapsed,
      summary: 'Workflow "${goal.title}" completado con éxito en ${executed.length} pasos (${stopwatch.elapsed.inMilliseconds}ms).',
    );
  }

  /// Consulta el perfil de capacidades registrado para una app objetivo.
  Future<AppProfile?> inspectTargetApp(String query) =>
      _capabilityRegistry.resolveProfile(query);
}
