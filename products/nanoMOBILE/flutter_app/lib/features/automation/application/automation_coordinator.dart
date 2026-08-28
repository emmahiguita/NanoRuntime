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
    show AgentToolDispatcher, PlanOutcome, ToolCall, ToolOutcome;
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
    show TaskPlan, TaskStepResult;
import 'package:nanoai/features/automation/engine/orchestration/task_planner.dart';
import 'package:nanoai/features/automation/engine/voice/execution_cancellation.dart';

import '../domain/automation_goal.dart' show AutomationGoal, AutomationOptions;
import '../domain/automation_policy.dart'
    show AgentAutomationMode, AutomationPolicy;
import '../domain/automation_result.dart'
    show AutomationResult, AutomationResultStatus;
import '../benchmark/c14_metrics.dart' show C14Execution;
import '../engine/execution/tool_registry.dart' show PolicyVerdict;
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

  /// A16 — cancelación cooperativa de la tarea activa (voz "para"/"cancela").
  final ExecutionCancellationToken _cancelToken = ExecutionCancellationToken();

  /// Cancela la tarea activa (cooperativo). Las acciones irreversibles ya
  /// completadas no se revierten; se detiene el trabajo pendiente.
  void cancelCurrent() => _cancelToken.cancel();

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
  bool requiresConfirmation(String tool) => _policy.requiresConfirmation(tool);

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
  tryDeterministic(String goal, {GoalExpectation? expectation}) async {
    final startedAt = DateTime.now();
    final cache = _cache;
    final flow = _flowExecutor;
    if (cache == null || flow == null) return null;
    final verified = cache.planFor(goal);
    if (verified == null) return null;
    final result = await flow.execute(
      NanoFlow(goal: goal, steps: verified.steps, goalExpectation: expectation),
    );
    // Degradar confianza SOLO en fallo REAL (no completado y SIN pausa).
    // Una pausa (pauseIndex != null) es un estado normal (pedir confirmación),
    // no un fallo — no debe degradar el flujo en cache.
    if (!result.completed && result.plan.pauseIndex == null) {
      cache.recordFailure(goal);
    }
    _record(
      goal: goal,
      status: _statusFromFlow(result),
      summary: result.plan.summary,
      pauseIndex: result.plan.pauseIndex,
      pauseTool: result.plan.pauseCall?.tool,
      startedAt: startedAt,
    );
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
  Future<List<TaskStepResult>?> runCrossAppTask(String goal) async {
    final orchestrator = _taskOrchestrator;
    if (orchestrator == null) return null;

    final TaskPlan? plan;
    final decomposer = _taskDecomposer;
    if (decomposer != null) {
      plan = await decomposer.decompose(goal);
    } else {
      plan = _taskPlanner?.plan(goal);
    }
    if (plan == null) return null;
    return orchestrator.run(plan, cancel: _cancelToken);
  }

  /// OBJETIVO está verificado satisfecho ([GoalVerifier]); un plan que
  /// completó a nivel pasos pero NO logró el objetivo NO se memoriza.
  Future<PlanOutcome> runPlan(
    List<ToolCall> plan, {
    bool confirmed = false,
    String? recordGoal,
    GoalExpectation? expectation,
  }) async {
    final startedAt = DateTime.now();
    final outcome = await _dispatcher.runPlanGuarded(
      plan,
      confirmed: confirmed,
    );
    if (recordGoal != null) {
      await _learn(recordGoal, plan, outcome, expectation);
    }
    _record(
      goal: recordGoal ?? (plan.isNotEmpty ? plan.first.tool : ''),
      status: _statusFromPlan(outcome),
      summary: outcome.summary,
      pauseIndex: outcome.pauseIndex,
      pauseTool: outcome.pauseCall?.tool,
      startedAt: startedAt,
    );
    return outcome;
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
  Future<ToolOutcome> runTool(ToolCall call, {bool confirmed = false}) async {
    final startedAt = DateTime.now();
    final outcome = await _dispatcher.runToolGuarded(
      call,
      confirmed: confirmed,
    );
    _record(
      goal: call.tool,
      status: _statusFromTool(outcome),
      summary: outcome.feedback,
      startedAt: startedAt,
    );
    return outcome;
  }

  /// Comando `@` determinista (autoría humana — confirmación implícita).
  Future<String> runCommand(String command) => _dispatcher.runCommand(command);

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
    final executionId = options?.executionId ?? _newId();

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

    // C11: solo una INSTRUCCIÓN real del usuario autoriza ejecutar. Un goal
    // vacío/espacio no es instrucción → noPlan (no se actúa sin orden).
    if (!InstructionTrust(userInstruction: goal.text).authorizesExecution()) {
      final r = AutomationResult(
        executionId: executionId,
        status: AutomationResultStatus.noPlan,
        reason: 'Sin instrucción autorizada del usuario.',
      );
      emit(r);
      return r;
    }

    if (plan == null) {
      // A15.0: seam cross-app multi-paso (0 LLM). Si el TaskPlanner matchea un
      // template determinista (guarda/abre el enlace), el TaskOrchestrator lo
      // ejecuta con data flow tipado ANTES del flujo simple (que es single-step).
      final crossApp = await runCrossAppTask(goal.text);
      if (crossApp != null) {
        // A15.3: telemetría cross-app (pasos de la tarea ejecutados).
        taskStepsCount = crossApp.length;
        TaskStepResult? firstFailed;
        for (final s in crossApp) {
          // T2.7: completedUnverified NO es fallo (paso ejecutado sin poder
          // verificar); solo failed/denied/needs* detienen como error.
          if (s.isFailure) {
            firstFailed = s;
            break;
          }
        }
        final r = AutomationResult(
          executionId: executionId,
          status: firstFailed == null
              ? AutomationResultStatus.completedUnverified
              : AutomationResultStatus.failed,
          reason: firstFailed == null
              ? 'Tarea cross-app completada (${crossApp.length} pasos).'
              : 'Tarea cross-app no completada: ${firstFailed.reason}',
        );
        emit(r);
        return r;
      }

      final deterministic = await tryDeterministic(
        goal.text,
        expectation: goal.expectation,
      );
      if (deterministic != null) {
        cacheHit = true;
        steps = deterministic.steps.length;
        final r = _resultFromFlow(executionId, deterministic.result);
        emit(r);
        return r;
      }

      // A13.5: Candidate-First pipeline (0 LLM para goals conocidos). Antes del
      // fallback legacy. Resuelto → ejecutar; Governed → resultado honesto;
      // NoCandidate/ambiguo → cae al legacy fallback.
      final candidateFirst = _candidateFirst;
      if (candidateFirst != null) {
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
          emit(r);
          return r;
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
          // Catálogo determinista (SIN LLM): objetivo conocido → flujo real.
          final known = _catalog?.forGoal(goal.text);
          if (known != null && known.steps.isNotEmpty) {
            plan = known.steps;
            runExpectation = goal.expectation ?? known.expectation;
            outputProvesGoal = known.outputProvesGoal;
          } else {
            // Sin flujo en cache ni catálogo: planear con el LLM local.
            final planner = _planner;
            if (planner == null) {
              final r = AutomationResult(
                executionId: executionId,
                status: AutomationResultStatus.noPlan,
                reason: 'Sin flujo verificado en cache ni plan provisto.',
              );
              emit(r);
              return r;
            }
            final planned = await planner.plan(goal.text);
            llmLatency = planned.llmLatency;
            generatedCount = planned.generated;
            rejectedCount = planned.rejected;
            if (planned.calls.isEmpty) {
              final r = AutomationResult(
                executionId: executionId,
                status: AutomationResultStatus.noPlan,
                reason:
                    'El planner LLM no produjo acciones verificables para el objetivo.',
              );
              emit(r);
              return r;
            }
            plan = planned.calls;
          }
        }
      }
    }

    // C10/C12: anclar selectores semánticos a selectores reales (memoria/percepción).
    plan = await _resolveSelectors(plan, goal.text);

    if (plan.length > 1) {
      steps = plan.length;
      final t = Stopwatch()..start();
      final outcome = await runPlan(
        plan,
        confirmed: confirmed,
        recordGoal: goal.text,
        expectation: runExpectation,
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
      emit(r);
      return r;
    }
    steps = 1;
    final t = Stopwatch()..start();
    final outcome = await runTool(plan.single, confirmed: confirmed);
    t.stop();
    toolLatency = t.elapsed;
    final base = _resultFromTool(executionId, outcome);
    final r = await _finalizeExecution(
      executionId: executionId,
      goal: goal.text,
      base: base,
      expectation: runExpectation,
      outputProvesGoal: outputProvesGoal,
    );
    _recordMemory(goal.text, plan, r.status);
    emit(r);
    return r;
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
      );

  AutomationResult _resultFromPlan(String id, PlanOutcome o) =>
      AutomationResult(
        executionId: id,
        status: _statusFromPlan(o),
        reason: o.summary,
        pauseIndex: o.pauseIndex,
        pauseTool: o.pauseCall?.tool,
      );

  AutomationResult _resultFromTool(String id, ToolOutcome o) =>
      AutomationResult(
        executionId: id,
        status: _statusFromTool(o),
        reason: o.feedback,
      );

  static int _seq = 0;
  static String _newId() =>
      'auto-${DateTime.now().microsecondsSinceEpoch}-${++_seq}';

  // ── Trazas (ledger) ───────────────────────────────────────────────────────

  AutomationResultStatus _statusFromFlow(FlowExecutionResult r) {
    if (r.plan.pauseIndex != null) return AutomationResultStatus.paused;
    if (!r.completed) return AutomationResultStatus.failed;
    return r.goal.status == GoalStatus.satisfied
        ? AutomationResultStatus.completed
        : AutomationResultStatus.completedUnverified;
  }

  AutomationResultStatus _statusFromPlan(PlanOutcome o) {
    if (o.pauseIndex != null) return AutomationResultStatus.paused;
    if (!o.completed) return AutomationResultStatus.failed;
    return AutomationResultStatus.completed;
  }

  AutomationResultStatus _statusFromTool(ToolOutcome o) => switch (o.verdict) {
    PolicyVerdict.needsConfirmation => AutomationResultStatus.paused,
    PolicyVerdict.denied => AutomationResultStatus.denied,
    // allow ≠ éxito: la ejecución PUEDE haber fallado (feedback '[notFound]',
    // '[timeout]', '[verify:...]'). Un tool permitido pero que falló es
    // FAILED, no completed — evita false success (mismo criterio tipado que
    // el dispatcher usa en runPlanGuarded vía _isFailedFeedback).
    PolicyVerdict.allow =>
      _isFailedFeedback(o.feedback)
          ? AutomationResultStatus.failed
          : AutomationResultStatus.completed,
  };

  /// Feedback de fallo: arranca con `[codigo]`/`[codigo:...]` (p.ej.
  /// `[notFound]`, `[policy]`). Los éxitos nunca empiezan con `[`.
  static bool _isFailedFeedback(String feedback) =>
      RegExp(r'^\[[a-zA-Z]+(:|\])').hasMatch(feedback);

  void _record({
    required String goal,
    required AutomationResultStatus status,
    required String summary,
    int? pauseIndex,
    String? pauseTool,
    required DateTime startedAt,
  }) {
    _ledger?.record(
      AutomationTrace(
        executionId: 'auto-${DateTime.now().microsecondsSinceEpoch}',
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
