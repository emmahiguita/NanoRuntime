/// AutomationCoordinator — único dueño del CICLO DE EJECUCIÓN de
/// automatización (SRP/DIP).
///
/// Responde a: "tengo un objetivo y un plan (o un flujo verificado en cache):
/// ¿lo ejecuto bajo política, verifico y devuelvo un resultado honesto?".
///
/// Es SOLO orquestación de ejecución. NO genera el plan desde el LLM (eso es
/// de los planners, aguas arriba) ni renderiza mensajes (eso es del llamador,
/// p.ej. el chat). Encapsula la gobernanza y las piezas del motor para que el
/// llamador no conozca `AgentLoop`/`ExperienceCache`/`NanoFlowExecutor`/
/// `ActionPathRouter`/adapters — un solo cerebro de ejecución.
library;

import 'package:nanoai/features/automation/engine/execution/agent_tool_dispatcher.dart'
    show
        AgentToolDispatcher,
        PlanOutcome,
        ToolCall,
        ToolExecutionStatus,
        ToolOutcome;
import 'package:nanoai/features/automation/engine/planning/automation_planner.dart'
    show AutomationPlanner;
import 'package:nanoai/features/automation/engine/memory/experience_cache.dart'
    show ExperienceCache;
import 'package:nanoai/features/automation/engine/memory/object_memory.dart'
    show NanoObjectMemory, UiObjectKey, UiSelectorEvidence;
import 'package:nanoai/features/automation/engine/perception/perception_mux.dart'
    show PerceptionMux;
import 'package:nanoai/features/automation/engine/planning/deterministic_catalog.dart'
    show DeterministicFlowCatalog;
import 'package:nanoai/features/automation/engine/trust/instruction_trust.dart'
    show InstructionTrust;
import 'package:nanoai/features/automation/engine/execution/goal_verifier.dart'
    show GoalExpectation, GoalStatus, GoalVerification;
import 'package:nanoai/features/automation/engine/execution/nano_flow.dart'
    show FlowExecutionResult, NanoFlow, NanoFlowExecutor;
import 'package:nanoai/features/automation/engine/system/app_launch_resolver.dart'
    show AppLaunchResolver;
import 'package:nanoai/features/automation/engine/governance/action_governance_pipeline.dart'
    show
        GovernanceApproved,
        GovernanceClarification,
        GovernanceConfirmation,
        GovernanceDenied,
        GovernanceMoreEvidence,
        GovernanceOutcome;
import 'package:nanoai/features/automation/engine/planning/candidate_first_planner.dart'
    show
        CandidateFirstPlanner,
        CandidatePlanGoverned,
        CandidatePlanNoCandidate,
        CandidatePlanResolved;
import 'package:nanoai/features/automation/engine/orchestration/task_decomposer.dart';
import 'package:nanoai/features/automation/engine/orchestration/task_orchestrator.dart';
import 'package:nanoai/features/automation/engine/orchestration/task_plan.dart'
    show TaskPlan, TaskStepResult, TaskStepStatus;
import 'package:nanoai/features/automation/engine/orchestration/task_planner.dart';
import 'package:nanoai/features/automation/engine/orchestration/automation_run.dart';
import 'package:nanoai/features/automation/engine/voice/execution_cancellation.dart';

import '../domain/automation_goal.dart' show AutomationGoal, AutomationOptions;
import '../domain/automation_policy.dart'
    show AgentAutomationMode, AutomationPolicy;
import '../domain/automation_result.dart'
    show AutomationResult, AutomationResultStatus;
import '../benchmark/c14_metrics.dart' show C14Execution;
import '../engine/execution/tool_registry.dart' show PolicyVerdict;
import '../engine/governance/action_confirmation.dart' show ActionConfirmation;
import '../engine/governance/rule_execution_authority.dart'
    show RuleExecutionAuthority;
import '../ledger/action_ledger.dart' show ActionLedger;
import '../ledger/automation_trace.dart' show AutomationTrace;

/// Coordinador del ciclo de ejecución. Inyecta sus dependencias (DIP).
class AutomationCoordinator {
  final ExperienceCache? _cache;
  final NanoFlowExecutor? _flowExecutor;
  final AgentToolDispatcher _dispatcher;

  /// Fuente del nivel de autonomía actual (puede cambiar en runtime vía
  /// settings). Se inyecta como función para no acoplar el coordinator a
  /// settings/Riverpod.
  final AgentAutomationMode Function() _mode;

  /// Ledger de ejecuciones reales (auditoría / C14). null = no trazar.
  final ActionLedger? _ledger;

  /// Planner REAL (LLM) para generar un plan cuando no hay flujo en cache ni
  /// plan provisto. null = no planear (devuelve noPlan).
  final AutomationPlanner? _planner;

  /// Sink de métricas del benchmark físico (C14). null = no emitir. Inyectable
  /// solo por el harness C14; el resto del módulo no lo usa.
  final void Function(C14Execution)? _c14Sink;

  /// Verificador de objetivo (GOAL level) para el aprendizaje SOUND. null =
  /// no se puede verificar → no se aprende (no memorizar planes no verificados).
  final Future<GoalVerification> Function(
    String goal, {
    required bool planCompleted,
    GoalExpectation? expectation,
  })?
  _verifyGoal;

  /// Catálogo determinista: flujos conocidos para objetivos comunes (funcionan
  /// SIN el modelo LLM). null = no usar (solo cache + planner).
  final DeterministicFlowCatalog? _catalog;

  /// C10 — memoria de identidad de objetos UI. Resuelve selectores semánticos a
  /// selectores VERIFICADOS (resourceId) + aprende de la verificación. Mutable
  /// (copy-on-write): registrar un acierto/fallo devuelve una memoria nueva.
  NanoObjectMemory? _objectMemory;

  /// C12 — perceptores de pantalla fusionados. Fallback en vivo cuando [C10] no
  /// tiene un selector verificado para el concepto. null = sin percepción.
  final PerceptionMux? _perceptionMux;

  /// A2 — resolvedor determinista de "abre <app>" grounded en el catálogo de
  /// apps instaladas. null = sin inventario (no se resuelven apps por nombre).
  final AppLaunchResolver? _appLaunch;

  /// A13.5 — planificador Candidate-First de producción (0 LLM para goals
  /// conocidos). null = sin pipeline (legacy fallback directo).
  final CandidateFirstPlanner? _candidateFirst;

  /// A15.0 — orquestador cross-app multi-paso con data flow tipado.
  final TaskPlanner? _taskPlanner;
  final TaskOrchestrator? _taskOrchestrator;

  /// A15.2 — descomposición (template determinista + LLM validado).
  final LlmTaskDecomposer? _taskDecomposer;

  /// Registro de ejecución, no owner de su estado. Cada valor [AutomationRun]
  /// posee su propia cancelación, evidencia, confirmación y lifecycle.
  final Map<String, AutomationRun> _activeRuns = {};

  /// Cancela la tarea activa (cooperativo). Las acciones irreversibles ya
  /// completadas no se revierten; se detiene el trabajo pendiente.
  void cancelCurrent() {
    if (_activeRuns.isEmpty) return;
    _activeRuns.values.last.cancellation.cancel();
  }

  /// Cancela únicamente la ejecución solicitada. Nunca afecta otro run activo.
  bool cancelExecution(String executionId) {
    final run = _activeRuns[executionId];
    if (run == null) return false;
    run.cancellation.cancel();
    return true;
  }

  /// A13.6 — callback para compartir la instancia de memoria actualizada con la
  /// DI (el notifier). null en tests/aislado.
  final void Function(NanoObjectMemory)? _onMemoryUpdate;

  /// Snapshot de solo lectura para diagnóstico/tests. La memoria interna sigue
  /// siendo copy-on-write y solo el coordinator puede reemplazarla.
  NanoObjectMemory? get objectMemorySnapshot => _objectMemory;

  AutomationCoordinator({
    required AgentToolDispatcher dispatcher,
    required AgentAutomationMode Function() mode,
    ExperienceCache? cache,
    NanoFlowExecutor? flowExecutor,
    ActionLedger? ledger,
    AutomationPlanner? planner,
    Future<GoalVerification> Function(
      String goal, {
      required bool planCompleted,
      GoalExpectation? expectation,
    })?
    verifyGoal,
    DeterministicFlowCatalog? catalog,
    NanoObjectMemory? objectMemory,
    PerceptionMux? perceptionMux,
    AppLaunchResolver? appLaunch,
    CandidateFirstPlanner? candidateFirst,
    TaskPlanner? taskPlanner,
    TaskOrchestrator? taskOrchestrator,
    LlmTaskDecomposer? taskDecomposer,
    void Function(NanoObjectMemory)? onMemoryUpdate,
    void Function(C14Execution)? c14Sink,
  }) : _dispatcher = dispatcher,
       _mode = mode,
       _cache = cache,
       _flowExecutor = flowExecutor,
       _ledger = ledger,
       _planner = planner,
       _verifyGoal = verifyGoal,
       _catalog = catalog,
       _objectMemory = objectMemory,
       _perceptionMux = perceptionMux,
       _appLaunch = appLaunch,
       _candidateFirst = candidateFirst,
       _taskPlanner = taskPlanner,
       _taskOrchestrator = taskOrchestrator,
       _taskDecomposer = taskDecomposer,
       _onMemoryUpdate = onMemoryUpdate,
       _c14Sink = c14Sink;

  AutomationPolicy get _policy => AutomationPolicy(_mode());

  /// Copia este coordinator con un sink de métricas C14 asociado (para el
  /// benchmark). Conserva las mismas dependencias; solo cambia el sink.
  AutomationCoordinator withSink(void Function(C14Execution) sink) =>
      AutomationCoordinator(
        dispatcher: _dispatcher,
        mode: _mode,
        cache: _cache,
        flowExecutor: _flowExecutor,
        ledger: _ledger,
        planner: _planner,
        verifyGoal: _verifyGoal,
        catalog: _catalog,
        objectMemory: _objectMemory,
        perceptionMux: _perceptionMux,
        appLaunch: _appLaunch,
        candidateFirst: _candidateFirst,
        taskPlanner: _taskPlanner,
        taskOrchestrator: _taskOrchestrator,
        taskDecomposer: _taskDecomposer,
        onMemoryUpdate: _onMemoryUpdate,
        c14Sink: sink,
      );

  /// Mapea un resultado de gobernanza (A11) a un [AutomationResult] honesto.
  AutomationResult _resultFromGoverned(
    String executionId,
    GovernanceOutcome outcome,
  ) {
    return switch (outcome) {
      GovernanceDenied(:final reason) => AutomationResult(
        executionId: executionId,
        status: AutomationResultStatus.denied,
        reason: 'Gobernanza denegó la acción: ${reason.name}.',
      ),
      GovernanceConfirmation(:final reason) => AutomationResult(
        executionId: executionId,
        status: AutomationResultStatus.paused,
        reason: 'Requiere confirmación: ${reason.name}.',
      ),
      GovernanceMoreEvidence(:final reason) => AutomationResult(
        executionId: executionId,
        status: AutomationResultStatus.noPlan,
        reason: 'Evidencia insuficiente: ${reason.name}.',
      ),
      GovernanceClarification(:final reason) => AutomationResult(
        executionId: executionId,
        status: AutomationResultStatus.paused,
        reason: 'Requiere clarificación: ${reason.name}.',
      ),
      GovernanceApproved() => AutomationResult(
        executionId: executionId,
        status: AutomationResultStatus.failed,
        reason: 'Estado de gobernanza inesperado.',
      ),
    };
  }

  // ── Política de gobernanza ────────────────────────────────────────────────

  /// ¿Este tool requiere confirmación humana antes de actuar? (modo actual).
  bool requiresConfirmation(String tool) =>
      _dispatcher.requiresConfirmation(tool);

  /// Descripción legible para mostrar al usuario por qué pide confirmación.
  String confirmationDescription(String tool) =>
      _policy.confirmationDescription(tool);

  // ── Camino determinista (C7→C8) ───────────────────────────────────────────

  /// Intenta resolver [goal] con un flujo VERIFICADO en cache (sin LLM).
  /// Devuelve null si no hay hit (el llamador usa el planner/LLM). Si el
  /// flujo no completa, degrada la confianza del flujo en cache (C7).
  /// Incluye las [steps] del flujo para que el llamador pueda reanudar si un
  /// paso del flujo pide confirmación ([FlowExecutionResult.plan.pauseIndex]).
  Future<({FlowExecutionResult result, List<ToolCall> steps})?>
  tryDeterministic(
    String goal, {
    GoalExpectation? expectation,
    AutomationRun? run,
    ActionConfirmation? confirmation,
  }) async {
    final startedAt = DateTime.now();
    final cache = _cache;
    final flow = _flowExecutor;
    if (cache == null || flow == null) return null;
    final verified = cache.planFor(goal);
    if (verified == null) return null;
    // La memoria nunca puede degradar el invariante de navegación. Un flujo
    // legacy multi-UI se invalida y se vuelve a planificar semánticamente.
    if (_dispatcher.requiresGoalDirectedExecution(verified.steps)) {
      cache.recordFailure(goal);
      return null;
    }
    if (run != null && confirmation != null) {
      throw StateError(
        'AutomationRun no puede combinarse con confirmación legacy',
      );
    }
    final flowRun =
        run ??
        AutomationRun(
          executionId: confirmation?.executionId ?? _newId(),
          goal: goal,
          confirmation: confirmation,
        );
    flowRun.beginPlanning();
    final result = await flow.execute(
      NanoFlow(goal: goal, steps: verified.steps, goalExpectation: expectation),
      confirmation: flowRun.confirmation,
      executionId: flowRun.executionId,
      cancellation: flowRun.cancellation,
      onStep: flowRun.enterStep,
    );
    if (result.plan.confirmation != null) {
      flowRun.waitForConfirmation(result.plan.confirmation!);
    } else {
      flowRun.beginVerification();
    }
    // Degradar confianza SOLO en fallo REAL (no completado y SIN pausa).
    // Una pausa (pauseIndex != null) es un estado normal (pedir confirmación),
    // no un fallo — no debe degradar el flujo en cache.
    if (!result.completed && result.plan.pauseIndex == null) {
      cache.recordFailure(goal);
    }
    _record(
      executionId: flowRun.executionId,
      goal: goal,
      status: _statusFromFlow(result),
      summary: result.plan.summary,
      pauseIndex: result.plan.pauseIndex,
      pauseTool: result.plan.pauseCall?.tool,
      startedAt: startedAt,
    );
    if (run == null) {
      flowRun.finish(
        status: _statusFromFlow(result).name,
        reason: result.plan.summary,
      );
    }
    return (result: result, steps: verified.steps);
  }

  /// Ejecuta exclusivamente un flujo conocido del catálogo, sin planner.
  ///
  /// Se mantiene separado de [tryDeterministic]: aquél representa memoria
  /// verificada (cache C7), mientras éste representa reglas estáticas
  /// revisadas. Devuelve null si el objetivo no es conocido.
  Future<({AutomationResult result, List<ToolCall> steps})?> tryKnownFlow(
    String goal,
  ) async {
    final known = _catalog?.forGoal(goal);
    if (known == null || known.steps.isEmpty) return null;
    // Dejar que execute resuelva nuevamente el catálogo conserva dentro de
    // una sola ruta la evidencia declarada por el flujo (outputProvesGoal).
    final result = await execute(
      AutomationGoal(text: goal, expectation: known.expectation),
    );
    return (result: result, steps: known.steps);
  }

  // ── Ejecución de plan / herramienta ───────────────────────────────────────

  /// Ejecuta un plan multi-paso bajo gobernanza. [recordGoal] != null →
  /// memoriza el resultado en cache (C7), PERO de forma SOUND: solo cuando el
  /// A15.0/A15.2 — seam cross-app: descompone el objetivo (template determinista
  /// primero, LLM validado después) y ejecuta el TaskOrchestrator con data flow
  /// tipado. null = no es un objetivo cross-app (usar el flujo simple).
  Future<List<TaskStepResult>?> runCrossAppTask(
    String goal, {
    AutomationRun? run,
    ActionConfirmation? confirmation,
    String? executionId,
    bool deterministicOnly = false,
  }) async {
    final orchestrator = _taskOrchestrator;
    if (orchestrator == null) return null;

    if (run != null &&
        (confirmation != null || executionId != null || run.goal != goal)) {
      return const [
        TaskStepResult(
          status: TaskStepStatus.failed,
          reason: 'ownership ambiguo o AutomationRun de otro objetivo',
        ),
      ];
    }
    final taskRun =
        run ??
        AutomationRun(
          executionId: executionId ?? confirmation?.executionId ?? _newId(),
          goal: goal,
          confirmation: confirmation,
        );
    final TaskPlan? plan;
    final decomposer = deterministicOnly ? null : _taskDecomposer;
    if (decomposer != null) {
      plan = await decomposer.decompose(goal);
    } else {
      plan = _taskPlanner?.plan(goal);
    }
    if (plan == null) return null;
    return orchestrator.run(plan, run: taskRun);
  }

  /// Intenta exclusivamente la ruta TaskPlanner/TaskOrchestrator. No invoca el
  /// planner LLM ni el catálogo legacy; permite al chat resolver lenguaje
  /// natural determinista antes de exigir un modelo cargado.
  Future<({AutomationResult result, List<TaskStepResult> steps})?> tryCrossApp(
    String goal, {
    AutomationRun? run,
    ActionConfirmation? confirmation,
    String? executionId,
    bool deterministicOnly = true,
  }) async {
    if (run != null && (confirmation != null || executionId != null)) {
      throw StateError('AutomationRun no puede combinarse con estado legacy');
    }
    final taskRun =
        run ??
        AutomationRun(
          executionId: executionId ?? confirmation?.executionId ?? _newId(),
          goal: goal,
          confirmation: confirmation,
        );
    final ownsRegistration = run == null;
    if (ownsRegistration && _activeRuns.containsKey(taskRun.executionId)) {
      final conflict = AutomationResult(
        executionId: taskRun.executionId,
        status: AutomationResultStatus.denied,
        reason: 'Ya existe una ejecución activa con este executionId.',
      );
      taskRun.finish(status: conflict.status.name, reason: conflict.reason);
      return (result: conflict, steps: const <TaskStepResult>[]);
    }
    if (ownsRegistration) {
      _activeRuns[taskRun.executionId] = taskRun;
    }
    try {
      final steps = await runCrossAppTask(
        goal,
        run: taskRun,
        deterministicOnly: deterministicOnly,
      );
      if (steps == null) {
        if (ownsRegistration) {
          taskRun.finish(status: 'noPlan', reason: 'Sin TaskPlan aplicable.');
        }
        return null;
      }

      TaskStepResult? firstFailed;
      TaskStepResult? paused;
      TaskStepResult? unknown;
      for (final step in steps) {
        if (!step.isFailure) continue;
        if (step.status == TaskStepStatus.needsConfirmation) paused = step;
        if (step.status == TaskStepStatus.outcomeUnknown) unknown = step;
        firstFailed = step;
        break;
      }
      final allVerified =
          steps.isNotEmpty && steps.every((step) => step.isCompleted);
      final result = AutomationResult(
        executionId: taskRun.executionId,
        status: taskRun.cancellation.isCancelled
            ? AutomationResultStatus.cancelled
            : paused != null
            ? AutomationResultStatus.paused
            : unknown != null
            ? AutomationResultStatus.outcomeUnknown
            : firstFailed == null
            ? allVerified
                  ? AutomationResultStatus.completed
                  : AutomationResultStatus.completedUnverified
            : AutomationResultStatus.failed,
        reason: taskRun.cancellation.isCancelled
            ? 'Ejecución cancelada por el usuario.'
            : paused != null
            ? paused.reason
            : firstFailed == null
            ? 'Tarea cross-app completada (${steps.length} pasos).'
            : 'Tarea cross-app no completada: ${firstFailed.reason}',
        pauseIndex: paused?.confirmation?.stepIndex,
        pauseTool: paused == null
            ? null
            : 'task:${paused.confirmation?.stepId}',
        confirmation: paused?.confirmation,
      );
      if (ownsRegistration) {
        taskRun.finish(status: result.status.name, reason: result.reason);
      }
      return (result: result, steps: steps);
    } finally {
      if (ownsRegistration) {
        _activeRuns.remove(taskRun.executionId);
      }
    }
  }

  /// OBJETIVO está verificado satisfecho ([GoalVerifier]); un plan que
  /// completó a nivel pasos pero NO logró el objetivo NO se memoriza.
  Future<PlanOutcome> runPlan(
    List<ToolCall> plan, {
    AutomationRun? run,
    ActionConfirmation? confirmation,
    String? executionId,
    bool confirmed = false,
    String? recordGoal,
    GoalExpectation? expectation,
    RuleExecutionAuthority? authority,
  }) async {
    if (run != null && (confirmation != null || executionId != null)) {
      throw StateError('AutomationRun no puede combinarse con estado legacy');
    }
    final planRun =
        run ??
        AutomationRun(
          executionId: executionId ?? confirmation?.executionId ?? _newId(),
          goal: recordGoal ?? (plan.isEmpty ? '' : plan.first.tool),
          confirmation: confirmation,
        );
    final ownsRegistration = run == null;
    if (ownsRegistration && _activeRuns.containsKey(planRun.executionId)) {
      return const PlanOutcome(
        completed: false,
        steps: [
          ToolOutcome(
            verdict: PolicyVerdict.denied,
            feedback: '[runConflict] executionId ya está activo.',
          ),
        ],
        summary: '[runConflict] executionId ya está activo.',
      );
    }
    if (ownsRegistration) _activeRuns[planRun.executionId] = planRun;
    final startedAt = DateTime.now();
    try {
      planRun.beginPlanning();
      final outcome = await _dispatcher.runPlanGuarded(
        plan,
        confirmation: planRun.confirmation,
        executionId: planRun.executionId,
        confirmed: confirmed,
        cancellation: planRun.cancellation,
        onStep: planRun.enterStep,
        authority: authority,
      );
      if (outcome.confirmation != null) {
        planRun.waitForConfirmation(outcome.confirmation!);
      } else {
        planRun.beginVerification();
      }
      if (recordGoal != null) {
        await _learn(recordGoal, plan, outcome, expectation);
      }
      _record(
        executionId: planRun.executionId,
        goal: recordGoal ?? (plan.isNotEmpty ? plan.first.tool : ''),
        status: _statusFromPlan(outcome),
        summary: outcome.summary,
        pauseIndex: outcome.pauseIndex,
        pauseTool: outcome.pauseCall?.tool,
        startedAt: startedAt,
      );
      if (ownsRegistration) {
        planRun.finish(
          status: _statusFromPlan(outcome).name,
          reason: outcome.summary,
        );
      }
      return outcome;
    } on ExecutionCancelled {
      if (!ownsRegistration) rethrow;
      const feedback = '[cancelled] Ejecución cancelada por el usuario.';
      const outcome = PlanOutcome(
        completed: false,
        steps: [ToolOutcome(verdict: PolicyVerdict.denied, feedback: feedback)],
        summary: feedback,
      );
      _record(
        executionId: planRun.executionId,
        goal: recordGoal ?? (plan.isNotEmpty ? plan.first.tool : ''),
        status: AutomationResultStatus.cancelled,
        summary: feedback,
        startedAt: startedAt,
      );
      if (ownsRegistration) {
        planRun.finish(status: 'cancelled', reason: feedback);
      }
      return outcome;
    } finally {
      if (ownsRegistration &&
          identical(_activeRuns[planRun.executionId], planRun)) {
        _activeRuns.remove(planRun.executionId);
      }
    }
  }

  /// Aprendizaje SOUND (C7): memorizar SOLO planes cuyo objetivo se verificó
  /// satisfecho. Sin expectativa o sin verifier → no aprender (evita memorizar
  /// planes que "completaron" a nivel pasos sin lograr el objetivo).
  Future<void> _learn(
    String goal,
    List<ToolCall> plan,
    PlanOutcome outcome,
    GoalExpectation? expectation,
  ) async {
    final cache = _cache;
    if (cache == null) return;
    if (!outcome.completed) {
      cache.recordFailure(goal);
      return;
    }
    if (expectation == null) return;
    final verify = _verifyGoal;
    if (verify == null) return;
    final v = await verify(goal, planCompleted: true, expectation: expectation);
    if (v.status == GoalStatus.satisfied) {
      cache.recordSuccess(goal, plan);
    } else {
      cache.recordFailure(goal);
    }
  }

  /// Ejecuta una herramienta suelta bajo gobernanza.
  Future<ToolOutcome> runTool(
    ToolCall call, {
    bool confirmed = false,
    String? executionId,
  }) async {
    final run = AutomationRun(
      executionId: executionId ?? _newId(),
      goal: call.tool,
    );
    if (_activeRuns.containsKey(run.executionId)) {
      return const ToolOutcome(
        verdict: PolicyVerdict.denied,
        feedback: '[runConflict] executionId ya está activo.',
      );
    }
    _activeRuns[run.executionId] = run;
    final startedAt = DateTime.now();
    try {
      run.beginPlanning();
      run.enterStep(0);
      // Una herramienta aislada no dispone de planSignature/paso/firma para
      // vincular consentimiento. El bool legacy jamás autoriza; los callers
      // autónomos sensibles deben usar execute(plan: [...]) y devolver el
      // ActionConfirmation exacto recibido en la pausa.
      final outcome = confirmed
          ? const ToolOutcome(
              verdict: PolicyVerdict.denied,
              feedback:
                  '[confirmationTokenRequired] La confirmación booleana no '
                  'autoriza una acción. Reanuda mediante ActionConfirmation.',
              executionStatus: ToolExecutionStatus.notExecuted,
            )
          : await _dispatcher.runToolGuarded(
              call,
              executionId: run.executionId,
              cancellation: run.cancellation,
            );
      if (!outcome.needsConfirmation) run.beginVerification();
      _record(
        executionId: run.executionId,
        goal: call.tool,
        status: _statusFromTool(outcome),
        summary: outcome.feedback,
        startedAt: startedAt,
      );
      run.finish(
        status: _statusFromTool(outcome).name,
        reason: outcome.feedback,
      );
      return outcome;
    } on ExecutionCancelled {
      const outcome = ToolOutcome(
        verdict: PolicyVerdict.denied,
        feedback: '[cancelled] Ejecución cancelada por el usuario.',
      );
      _record(
        executionId: run.executionId,
        goal: call.tool,
        status: AutomationResultStatus.cancelled,
        summary: outcome.feedback,
        startedAt: startedAt,
      );
      run.finish(status: 'cancelled', reason: outcome.feedback);
      return outcome;
    } finally {
      if (identical(_activeRuns[run.executionId], run)) {
        _activeRuns.remove(run.executionId);
      }
    }
  }

  /// Comando `@` determinista (autoría humana — confirmación implícita).
  Future<String> runCommand(String command) async {
    final run = AutomationRun(executionId: _newId(), goal: command);
    _activeRuns[run.executionId] = run;
    try {
      run.beginPlanning();
      run.enterStep(0);
      final feedback = await _dispatcher.runCommand(
        command,
        executionId: run.executionId,
        cancellation: run.cancellation,
      );
      if (run.cancellation.isCancelled) {
        const cancelled = '[cancelled] Ejecución cancelada por el usuario.';
        run.finish(status: 'cancelled', reason: cancelled);
        return cancelled;
      }
      run.beginVerification();
      run.finish(status: 'returned', reason: feedback);
      return feedback;
    } on ExecutionCancelled {
      const cancelled = '[cancelled] Ejecución cancelada por el usuario.';
      run.finish(status: 'cancelled', reason: cancelled);
      return cancelled;
    } finally {
      if (identical(_activeRuns[run.executionId], run)) {
        _activeRuns.remove(run.executionId);
      }
    }
  }

  /// Resetea el estado del turno del dispatcher (ciclo de vida de una ronda).
  void reset() => _dispatcher.resetTurn();

  // ── Entrada única del módulo ──────────────────────────────────────────────

  /// Ejecuta un [AutomationGoal] hasta un [AutomationResult] honesto.
  ///
  /// Punto de entrada ÚNICO del módulo (para chat, notificaciones, voz,
  /// eventos). Decide el camino:
  ///   1. Sin [plan] → flujo verificado en cache (C7→C8) si hay hit.
  ///   2. Sin [plan] y sin hit → el [AutomationPlanner] REAL genera un plan
  ///      con el LLM local y se ejecuta bajo gobernanza (motor autónomo).
  ///   3. Con [plan] (del LLM) → lo ejecuta bajo gobernanza (multi-paso o
  ///      tool única) y memoriza en cache (C7).
  ///
  /// NO renderiza (eso es del llamador). Registra la ejecución en el ledger.
  /// Nunca lanza por fallos de negocio: todo término es un [AutomationResult].
  Future<AutomationResult> execute(
    AutomationGoal goal, {
    List<ToolCall>? plan,
    AutomationOptions? options,
  }) async {
    final sw = Stopwatch()..start();
    final confirmed = options?.confirmed ?? false;
    final confirmation = options?.confirmation;
    // Una reanudación debe conservar la identidad firmada por el token. La UI
    // solo necesita devolver la confirmación recibida; generar aquí un id
    // nuevo hacía que el journal rechazara siempre su propio token.
    final executionId =
        options?.executionId ?? confirmation?.executionId ?? _newId();
    if (_activeRuns.containsKey(executionId)) {
      return AutomationResult(
        executionId: executionId,
        status: AutomationResultStatus.denied,
        reason: 'Ya existe una ejecución activa con este executionId.',
      );
    }
    final run = AutomationRun(
      executionId: executionId,
      goal: goal.text,
      confirmation: confirmation,
    );
    _activeRuns[executionId] = run;

    // Métricas C14 acumuladas a lo largo del camino (diagnóstico del planner).
    var cacheHit = false;
    var llmLatency = Duration.zero;
    var toolLatency = Duration.zero;
    var generatedCount = 0;
    var rejectedCount = 0;
    var steps = 0;
    // A13.6: métricas Candidate-First / legacy (observabilidad C14).
    var candidateCount = 0;
    var selectionMode = 'none';
    var koogInvoked = false;
    var legacyFallback = false;
    var candidateLatency = Duration.zero;
    // A15.3: métricas de tareas cross-app multi-paso.
    var taskStepsCount = 0;
    var zeroLlmTask = false;
    var deterministicCrossAppAttempted = false;
    var semanticFallbackAttempted = false;
    // Expectativa efectiva para el run (usada en aprendizaje SOUND). Por defecto
    // la del goal; un flujo determinista del catálogo puede aportar la suya.
    var runExpectation = goal.expectation;
    var outputProvesGoal = false;

    void emit(AutomationResult r) {
      final sink = _c14Sink;
      if (sink == null) return;
      sink(
        C14Execution(
          goal: goal.text,
          planValid: r.status != AutomationResultStatus.noPlan,
          toolsGenerated: generatedCount,
          toolsRejected: rejectedCount,
          steps: steps,
          path: cacheHit ? 'cache' : (generatedCount > 0 ? 'llm' : 'none'),
          llmLatency: llmLatency,
          toolLatency: toolLatency,
          verification: r.status,
          retries: 0,
          replans: 0,
          cacheHit: cacheHit,
          goalSuccess: r.isVerifiedSuccess,
          totalLatency: sw.elapsed,
          candidateCount: candidateCount,
          selectionMode: selectionMode,
          koogInvoked: koogInvoked,
          legacyFallback: legacyFallback,
          candidateLatency: candidateLatency,
          taskSteps: taskStepsCount,
          zeroLlmTask: zeroLlmTask,
        ),
      );
    }

    AutomationResult finish(AutomationResult result) {
      emit(result);
      run.finish(status: result.status.name, reason: result.reason);
      return result;
    }

    try {
      run.beginPlanning();
      run.cancellation.throwIfCancelled();
      // C11: solo una INSTRUCCIÓN real del usuario autoriza ejecutar. Un goal
      // vacío/espacio no es instrucción → noPlan (no se actúa sin orden).
      if (!InstructionTrust(userInstruction: goal.text).authorizesExecution()) {
        final r = AutomationResult(
          executionId: executionId,
          status: AutomationResultStatus.noPlan,
          reason: 'Sin instrucción autorizada del usuario.',
        );
        return finish(r);
      }

      if (plan == null) {
        // A15.0: seam cross-app multi-paso (0 LLM). Si el TaskPlanner matchea un
        // template determinista (guarda/abre el enlace), el TaskOrchestrator lo
        // ejecuta con data flow tipado ANTES del flujo simple (que es single-step).
        deterministicCrossAppAttempted = true;
        final crossApp = await tryCrossApp(goal.text, run: run);
        if (crossApp != null) {
          // A15.3: telemetría cross-app (pasos de la tarea ejecutados).
          taskStepsCount = crossApp.steps.length;
          zeroLlmTask = true;
          final r = crossApp.result;
          return finish(r);
        }

        final deterministic = await tryDeterministic(
          goal.text,
          expectation: goal.expectation,
          run: run,
        );
        if (deterministic != null) {
          cacheHit = true;
          steps = deterministic.steps.length;
          final r = _resultFromFlow(executionId, deterministic.result);
          return finish(r);
        }

        // Un objetivo exacto del catálogo ya tiene semántica y evidencia
        // revisadas: ejecutarlo antes de Candidate-First evita convertir una
        // orden determinista en una selección LLM innecesaria.
        final known = _catalog?.forGoal(goal.text);
        if (known != null && known.steps.isNotEmpty) {
          plan = known.steps;
          runExpectation = goal.expectation ?? known.expectation;
          outputProvesGoal = known.outputProvesGoal;
        }

        // A13.5: Candidate-First queda reservado para objetivos que el catálogo
        // no resolvió. Resuelto → ejecutar; Governed → resultado honesto;
        // NoCandidate/ambiguo → cae al fallback siguiente.
        final candidateFirst = _candidateFirst;
        if (plan == null && candidateFirst != null) {
          final swCandidate = Stopwatch()..start();
          final candidatePlan = await candidateFirst.plan(goal.text);
          swCandidate.stop();
          candidateLatency = swCandidate.elapsed;
          if (candidatePlan is CandidatePlanResolved) {
            plan = [candidatePlan.call];
            runExpectation = candidatePlan.expectation;
            selectionMode = candidatePlan.selectionMode.name;
            koogInvoked = candidatePlan.koogInvoked;
            candidateCount = candidatePlan.candidateCount;
          } else if (candidatePlan is CandidatePlanGoverned) {
            final r = _resultFromGoverned(executionId, candidatePlan.outcome);
            return finish(r);
          } else if (candidatePlan is CandidatePlanNoCandidate) {
            candidateCount = candidatePlan.candidateCount;
            legacyFallback = true;
            selectionMode = 'legacyFallback';
          }
        }

        if (plan == null) {
          // A2: resolvedor grounded de "abre <app>" — package REAL del
          // PackageManager, nunca un package inventado por el modelo. Precede al
          // catálogo estático para que "abre Chrome" use el catálogo real.
          final appLaunch = _appLaunch;
          final launchPlan = appLaunch == null
              ? null
              : await appLaunch.resolve(goal.text);
          if (launchPlan != null) {
            plan = [launchPlan.call];
            runExpectation = launchPlan.expectation;
          } else {
            // AUT-15: solo después de agotar memoria, catálogo, candidatos e
            // inventario, permitir descomposición LLM a semántica finita.
            // El decomposer aplica AutomationModelResolver y nunca emite
            // tools, paquetes, selectores ni coordenadas arbitrarias.
            semanticFallbackAttempted = true;
            final semanticFallback = await tryCrossApp(
              goal.text,
              run: run,
              deterministicOnly: false,
            );
            if (semanticFallback != null) {
              taskStepsCount = semanticFallback.steps.length;
              zeroLlmTask = false;
              return finish(semanticFallback.result);
            }

            // Sin flujo en cache ni catálogo: planear con el LLM local.
            final planner = _planner;
            if (planner == null) {
              final r = AutomationResult(
                executionId: executionId,
                status: AutomationResultStatus.noPlan,
                reason: 'Sin flujo verificado en cache ni plan provisto.',
              );
              return finish(r);
            }
            run.cancellation.throwIfCancelled();
            final planned = await planner.plan(goal.text);
            run.cancellation.throwIfCancelled();
            llmLatency = planned.llmLatency;
            generatedCount = planned.generated;
            rejectedCount = planned.rejected;
            if (planned.calls.isEmpty) {
              final r = AutomationResult(
                executionId: executionId,
                status: AutomationResultStatus.noPlan,
                reason:
                    planned.unavailableReason ??
                    'El planner LLM no produjo acciones verificables para el objetivo.',
              );
              return finish(r);
            }
            plan = planned.calls;
          }
        }
      }

      // Un array de gestos UI generado por un modelo no se ejecuta en cadena.
      // Se reconstruye como TaskPlan y TaskOrchestrator reobserva el mundo tras
      // cada acción. Si la intención no cabe en el vocabulario semántico real,
      // se detiene honestamente en lugar de actuar a ciegas.
      if (_dispatcher.requiresGoalDirectedExecution(plan)) {
        if (!deterministicCrossAppAttempted) {
          final deterministicGoalDirected = await tryCrossApp(
            goal.text,
            run: run,
          );
          if (deterministicGoalDirected != null) {
            taskStepsCount = deterministicGoalDirected.steps.length;
            zeroLlmTask = true;
            return finish(deterministicGoalDirected.result);
          }
        }
        if (!semanticFallbackAttempted) {
          final goalDirected = await tryCrossApp(
            goal.text,
            run: run,
            deterministicOnly: false,
          );
          if (goalDirected != null) {
            taskStepsCount = goalDirected.steps.length;
            zeroLlmTask = false;
            return finish(goalDirected.result);
          }
        }
        final r = AutomationResult(
          executionId: executionId,
          status: AutomationResultStatus.noPlan,
          reason:
              'El plan visual requiere navegación orientada a objetivos, pero '
              'no produjo un TaskPlan semántico verificable. No se ejecutó.',
        );
        return finish(r);
      }

      // C10/C12: anclar selectores semánticos a selectores reales (memoria/percepción).
      run.cancellation.throwIfCancelled();
      plan = await _resolveSelectors(plan, goal.text);
      run.cancellation.throwIfCancelled();

      // Una única acción usa la misma ruta gobernada que un plan de varios
      // pasos. Así no existe una puerta de confirmación paralela capaz de
      // aceptar un bool genérico ni de perder executionId/plan/paso/acción.
      steps = plan.length;
      final t = Stopwatch()..start();
      final outcome = await runPlan(
        plan,
        run: run,
        confirmed: confirmed,
        recordGoal: goal.text,
        expectation: runExpectation,
        authority: options?.authority,
      );
      t.stop();
      toolLatency = t.elapsed;
      final base = _resultFromPlan(executionId, outcome);
      final r = await _finalizeExecution(
        executionId: executionId,
        goal: goal.text,
        base: base,
        expectation: runExpectation,
        outputProvesGoal: outputProvesGoal,
      );
      _recordMemory(goal.text, plan, r.status);
      return finish(r);
    } on ExecutionCancelled {
      return finish(
        AutomationResult(
          executionId: executionId,
          status: AutomationResultStatus.cancelled,
          reason: 'Ejecución cancelada por el usuario.',
        ),
      );
    } finally {
      if (identical(_activeRuns[executionId], run)) {
        _activeRuns.remove(executionId);
      }
    }
  }

  // ── C10: memoria de objetos UI ─────────────────────────────────────────────

  /// Ancla selectores semánticos (text=/desc=) a un selector REAL:
  /// primero C10 (resourceId verificado en memoria) y, si miss, C12 (percepción
  /// en vivo vía perceptionMux). Nunca inventa: si nada resuelve, deja el
  /// selector original (el executor fallará honesto).
  Future<List<ToolCall>> _resolveSelectors(
    List<ToolCall> plan,
    String goal,
  ) async {
    final mux = _perceptionMux;
    final resolved = <ToolCall>[];
    for (final c in plan) {
      final sel = c.selector ?? '';
      final concept = _conceptFromSelector(sel);
      final semantic =
          sel.startsWith('text=') ||
          sel.startsWith('text~=') ||
          sel.startsWith('desc=') ||
          sel.startsWith('desc~=');
      if (semantic && concept.isNotEmpty) {
        var used = sel;
        // PerceptionMux es el owner de percepción: memory-first + accessibility
        // + OCR. Sin split-brain: el coordinator ya no consulta memoria aparte.
        if (mux != null) {
          final perceived = await mux.resolve(concept);
          if (perceived != null) used = perceived;
        }
        resolved.add(ToolCall(tool: c.tool, selector: used, text: c.text));
      } else {
        resolved.add(c);
      }
    }
    return resolved;
  }

  String _conceptFromSelector(String selector) {
    final s = selector.trim();
    if (s.startsWith('text~=')) return s.substring(6).trim().toLowerCase();
    if (s.startsWith('desc~=')) return s.substring(6).trim().toLowerCase();
    if (s.startsWith('text=')) return s.substring(5).trim().toLowerCase();
    if (s.startsWith('desc=')) return s.substring(5).trim().toLowerCase();
    if (s.startsWith('id=')) return s.substring(3).trim().toLowerCase();
    return s.toLowerCase();
  }

  UiSelectorEvidence? _evidenceFromSelector(String selector) {
    final s = selector.trim();
    if (s.startsWith('id=')) {
      return UiSelectorEvidence(resourceId: s.substring(3).trim());
    }
    if (s.startsWith('text~=')) {
      return UiSelectorEvidence(text: s.substring(6).trim());
    }
    if (s.startsWith('text=')) {
      return UiSelectorEvidence(text: s.substring(5).trim());
    }
    if (s.startsWith('desc~=')) {
      return UiSelectorEvidence(desc: s.substring(6).trim());
    }
    if (s.startsWith('desc=')) {
      return UiSelectorEvidence(desc: s.substring(5).trim());
    }
    return null;
  }

  /// Memoriza la verificación del objetivo para anclar selectores futuros.
  /// RESOLUTION adapta; la VERIFICACIÓN ya fue estricta aguas arriba.
  void _recordMemory(
    String goal,
    List<ToolCall> plan,
    AutomationResultStatus status,
  ) {
    final mem = _objectMemory;
    if (mem == null || plan.isEmpty) return;

    // completedUnverified NO es evidencia positiva ni negativa.
    final verifiedSuccess = status == AutomationResultStatus.completed;
    final verifiedFailure = status == AutomationResultStatus.failed;
    if (!verifiedSuccess && !verifiedFailure) return;

    var next = mem;
    for (final c in plan) {
      final sel = c.selector ?? '';
      final concept = _conceptFromSelector(sel);
      if (concept.isEmpty) continue;
      final key = UiObjectKey(concept: concept);
      if (verifiedSuccess) {
        final evidence = _evidenceFromSelector(sel);
        if (evidence == null || evidence.fingerprint.isEmpty) continue;
        next = next.recordSuccess(key, evidence);
      } else {
        next = next.recordFailure(key);
      }
    }
    _objectMemory = next;
    _onMemoryUpdate?.call(next);
  }

  /// Normaliza ACTION/PLAN success a TASK success. Ningún camino de
  /// [execute] puede devolver `completed` si el objetivo final no fue probado.
  Future<AutomationResult> _finalizeExecution({
    required String executionId,
    required String goal,
    required AutomationResult base,
    GoalExpectation? expectation,
    bool outputProvesGoal = false,
  }) async {
    if (base.status != AutomationResultStatus.completed) return base;

    final verify = _verifyGoal;
    if (expectation == null && outputProvesGoal) {
      return AutomationResult(
        executionId: executionId,
        status: AutomationResultStatus.completed,
        reason: '${base.reason} Resultado nativo devuelto al usuario.',
        pauseIndex: base.pauseIndex,
        pauseTool: base.pauseTool,
      );
    }
    if (verify == null || expectation == null) {
      return AutomationResult(
        executionId: executionId,
        status: AutomationResultStatus.completedUnverified,
        reason: '${base.reason} Objetivo final sin verificación declarada.',
        pauseIndex: base.pauseIndex,
        pauseTool: base.pauseTool,
      );
    }

    final v = await verify(goal, planCompleted: true, expectation: expectation);
    return switch (v.status) {
      GoalStatus.satisfied => AutomationResult(
        executionId: executionId,
        status: AutomationResultStatus.completed,
        reason: '${base.reason} ${v.reason}',
        pauseIndex: base.pauseIndex,
        pauseTool: base.pauseTool,
      ),
      GoalStatus.unverified => AutomationResult(
        executionId: executionId,
        status: AutomationResultStatus.completedUnverified,
        reason: '${base.reason} ${v.reason}',
        pauseIndex: base.pauseIndex,
        pauseTool: base.pauseTool,
      ),
      GoalStatus.notSatisfied => AutomationResult(
        executionId: executionId,
        status: AutomationResultStatus.failed,
        reason: '${base.reason} ${v.reason}',
        pauseIndex: base.pauseIndex,
        pauseTool: base.pauseTool,
      ),
    };
  }

  // ── Resultado (mapeo a dominio) ───────────────────────────────────────────

  AutomationResult _resultFromFlow(String id, FlowExecutionResult r) =>
      AutomationResult(
        executionId: id,
        status: _statusFromFlow(r),
        reason: r.plan.summary,
        pauseIndex: r.plan.pauseIndex,
        pauseTool: r.plan.pauseCall?.tool,
        confirmation: r.plan.confirmation,
      );

  AutomationResult _resultFromPlan(String id, PlanOutcome o) =>
      AutomationResult(
        executionId: id,
        status: _statusFromPlan(o),
        reason: o.summary,
        pauseIndex: o.pauseIndex,
        pauseTool: o.pauseCall?.tool,
        confirmation: o.confirmation,
      );

  static int _seq = 0;
  static String _newId() =>
      'auto-${DateTime.now().microsecondsSinceEpoch}-${++_seq}';

  // ── Trazas (ledger) ───────────────────────────────────────────────────────

  AutomationResultStatus _statusFromFlow(FlowExecutionResult r) {
    if (r.plan.pauseIndex != null) return AutomationResultStatus.paused;
    if (r.plan.steps.any(
      (step) => step.executionStatus == ToolExecutionStatus.outcomeUnknown,
    )) {
      return AutomationResultStatus.outcomeUnknown;
    }
    if (!r.completed) return AutomationResultStatus.failed;
    return r.goal.status == GoalStatus.satisfied
        ? AutomationResultStatus.completed
        : AutomationResultStatus.completedUnverified;
  }

  AutomationResultStatus _statusFromPlan(PlanOutcome o) {
    if (o.pauseIndex != null) return AutomationResultStatus.paused;
    if (o.steps.any(
      (step) => step.executionStatus == ToolExecutionStatus.outcomeUnknown,
    )) {
      return AutomationResultStatus.outcomeUnknown;
    }
    if (!o.completed) return AutomationResultStatus.failed;
    return o.hasUnverifiedSteps
        ? AutomationResultStatus.completedUnverified
        : AutomationResultStatus.completed;
  }

  AutomationResultStatus _statusFromTool(ToolOutcome o) => switch (o.verdict) {
    PolicyVerdict.needsConfirmation => AutomationResultStatus.paused,
    PolicyVerdict.denied => AutomationResultStatus.denied,
    // allow ≠ éxito: la ejecución PUEDE haber fallado (feedback '[notFound]',
    // '[timeout]', '[verify:...]'). Un tool permitido pero que falló es
    // FAILED, no completed — evita false success (mismo criterio tipado que
    // el dispatcher usa en runPlanGuarded vía _isFailedFeedback).
    PolicyVerdict.allow => switch (o.executionStatus) {
      ToolExecutionStatus.completed => AutomationResultStatus.completed,
      ToolExecutionStatus.completedUnverified =>
        AutomationResultStatus.completedUnverified,
      ToolExecutionStatus.outcomeUnknown =>
        AutomationResultStatus.outcomeUnknown,
      ToolExecutionStatus.failed ||
      ToolExecutionStatus.notExecuted => AutomationResultStatus.failed,
    },
  };

  void _record({
    required String executionId,
    required String goal,
    required AutomationResultStatus status,
    required String summary,
    int? pauseIndex,
    String? pauseTool,
    required DateTime startedAt,
  }) {
    _ledger?.record(
      AutomationTrace(
        executionId: executionId,
        goal: goal,
        status: status,
        summary: summary,
        pauseIndex: pauseIndex,
        pauseTool: pauseTool,
        startedAt: startedAt,
        endedAt: DateTime.now(),
      ),
    );
  }
}
