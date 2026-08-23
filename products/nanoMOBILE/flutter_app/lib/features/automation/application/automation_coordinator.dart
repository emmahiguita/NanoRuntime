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
import 'package:nanoai/features/automation/engine/memory/experience_cache.dart' show ExperienceCache;
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

import '../domain/automation_goal.dart' show AutomationGoal, AutomationOptions;
import '../domain/automation_policy.dart' show AgentAutomationMode, AutomationPolicy;
import '../domain/automation_result.dart' show AutomationResult, AutomationResultStatus;
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
  })? _verifyGoal;

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
    })? verifyGoal,
    DeterministicFlowCatalog? catalog,
    NanoObjectMemory? objectMemory,
    PerceptionMux? perceptionMux,
    void Function(C14Execution)? c14Sink,
  })  : _dispatcher = dispatcher,
        _mode = mode,
        _cache = cache,
        _flowExecutor = flowExecutor,
        _ledger = ledger,
        _planner = planner,
        _verifyGoal = verifyGoal,
        _catalog = catalog,
        _objectMemory = objectMemory,
        _perceptionMux = perceptionMux,
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
        c14Sink: sink,
      );

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
      tryDeterministic(
    String goal, {
    GoalExpectation? expectation,
  }) async {
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

  // ── Ejecución de plan / herramienta ───────────────────────────────────────

  /// Ejecuta un plan multi-paso bajo gobernanza. [recordGoal] != null →
  /// memoriza el resultado en cache (C7), PERO de forma SOUND: solo cuando el
  /// OBJETIVO está verificado satisfecho ([GoalVerifier]); un plan que
  /// completó a nivel pasos pero NO logró el objetivo NO se memoriza.
  Future<PlanOutcome> runPlan(
    List<ToolCall> plan, {
    bool confirmed = false,
    String? recordGoal,
    GoalExpectation? expectation,
  }) async {
    final startedAt = DateTime.now();
    final outcome = await _dispatcher.runPlanGuarded(plan, confirmed: confirmed);
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
    final outcome = await _dispatcher.runToolGuarded(call, confirmed: confirmed);
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
    // Expectativa efectiva para el run (usada en aprendizaje SOUND). Por defecto
    // la del goal; un flujo determinista del catálogo puede aportar la suya.
    var runExpectation = goal.expectation;

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
          goalSuccess: r.status == AutomationResultStatus.completed ||
              r.status == AutomationResultStatus.completedUnverified,
          totalLatency: sw.elapsed,
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
      final deterministic =
          await tryDeterministic(goal.text, expectation: goal.expectation);
      if (deterministic != null) {
        cacheHit = true;
        steps = deterministic.steps.length;
        final r = _resultFromFlow(executionId, deterministic.result);
        emit(r);
        return r;
      }

      // Catálogo determinista (SIN LLM): objetivo conocido → flujo real.
      final known = _catalog?.forGoal(goal.text);
      if (known != null && known.steps.isNotEmpty) {
        plan = known.steps;
        runExpectation = goal.expectation ?? known.expectation;
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
      final r = _resultFromPlan(executionId, outcome);
      _recordMemory(goal.text, plan, r.status);
      emit(r);
      return r;
    }
    steps = 1;
    final t = Stopwatch()..start();
    final outcome = await runTool(plan.single, confirmed: confirmed);
    t.stop();
    toolLatency = t.elapsed;
    final r = _resultFromTool(executionId, outcome);
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
    final mem = _objectMemory;
    final mux = _perceptionMux;
    final key = UiObjectKey(concept: goal.toLowerCase());
    final resolved = <ToolCall>[];
    for (final c in plan) {
      final sel = c.selector ?? '';
      if (sel.startsWith('text=') || sel.startsWith('desc=')) {
        final concept = sel.substring(5).trim();
        var used = sel;
        final rid = mem?.resolve(key)?.resourceId;
        if (rid != null && rid.isNotEmpty) {
          used = 'id=$rid';
        } else if (mux != null) {
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

  /// Memoriza la verificación del objetivo para anclar selectores futuros.
  /// RESOLUTION adapta; la VERIFICACIÓN ya fue estricta aguas arriba.
  void _recordMemory(
    String goal,
    List<ToolCall> plan,
    AutomationResultStatus status,
  ) {
    final mem = _objectMemory;
    if (mem == null || plan.isEmpty) return;
    final key = UiObjectKey(concept: goal.toLowerCase());
    final ok = status == AutomationResultStatus.completed ||
        status == AutomationResultStatus.completedUnverified;
    var next = mem;
    for (final c in plan) {
      final sel = c.selector ?? '';
      final evidence = UiSelectorEvidence(
        resourceId: sel.startsWith('id=') ? sel.substring(3) : null,
        text: sel.startsWith('text=') ? sel.substring(5) : null,
      );
      next = ok ? next.recordSuccess(key, evidence) : next.recordFailure(key);
    }
    _objectMemory = next;
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

  AutomationResult _resultFromPlan(String id, PlanOutcome o) => AutomationResult(
        executionId: id,
        status: _statusFromPlan(o),
        reason: o.summary,
        pauseIndex: o.pauseIndex,
        pauseTool: o.pauseCall?.tool,
      );

  AutomationResult _resultFromTool(String id, ToolOutcome o) => AutomationResult(
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
        PolicyVerdict.allow => _isFailedFeedback(o.feedback)
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
