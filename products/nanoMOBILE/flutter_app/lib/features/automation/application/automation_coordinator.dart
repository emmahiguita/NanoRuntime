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

import 'package:nanoai/features/automation/engine/agent_tool_dispatcher.dart'
    show AgentToolDispatcher, PlanOutcome, ToolCall, ToolOutcome;
import 'package:nanoai/features/automation/engine/automation_planner.dart'
    show AutomationPlanner;
import 'package:nanoai/features/automation/engine/experience_cache.dart' show ExperienceCache;
import 'package:nanoai/features/automation/engine/goal_verifier.dart'
    show GoalExpectation, GoalStatus;
import 'package:nanoai/features/automation/engine/nano_flow.dart'
    show FlowExecutionResult, NanoFlow, NanoFlowExecutor;

import '../domain/automation_goal.dart' show AutomationGoal, AutomationOptions;
import '../domain/automation_policy.dart' show AgentAutomationMode, AutomationPolicy;
import '../domain/automation_result.dart' show AutomationResult, AutomationResultStatus;
import '../engine/tool_registry.dart' show PolicyVerdict;
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

  AutomationCoordinator({
    required AgentToolDispatcher dispatcher,
    required AgentAutomationMode Function() mode,
    ExperienceCache? cache,
    NanoFlowExecutor? flowExecutor,
    ActionLedger? ledger,
    AutomationPlanner? planner,
  })  : _dispatcher = dispatcher,
        _mode = mode,
        _cache = cache,
        _flowExecutor = flowExecutor,
        _ledger = ledger,
        _planner = planner;

  AutomationPolicy get _policy => AutomationPolicy(_mode());

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
    if (!result.completed) {
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
  /// memoriza el resultado en cache (C7): SOLO la ejecución inicial registra
  /// (el resume tras confirmación no). Devuelve el [PlanOutcome].
  Future<PlanOutcome> runPlan(
    List<ToolCall> plan, {
    bool confirmed = false,
    String? recordGoal,
  }) async {
    final startedAt = DateTime.now();
    final outcome = await _dispatcher.runPlanGuarded(plan, confirmed: confirmed);
    if (recordGoal != null) {
      if (outcome.completed) {
        _cache?.recordSuccess(recordGoal, plan);
      } else {
        _cache?.recordFailure(recordGoal);
      }
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
    final confirmed = options?.confirmed ?? false;
    final executionId = options?.executionId ?? _newId();

    if (plan == null) {
      final deterministic =
          await tryDeterministic(goal.text, expectation: goal.expectation);
      if (deterministic != null) {
        return _resultFromFlow(executionId, deterministic.result);
      }

      // Sin flujo en cache: planear con el LLM local (motor autónomo).
      final planner = _planner;
      if (planner == null) {
        return AutomationResult(
          executionId: executionId,
          status: AutomationResultStatus.noPlan,
          reason: 'Sin flujo verificado en cache ni plan provisto.',
        );
      }
      final generated = await planner.plan(goal.text);
      if (generated.isEmpty) {
        return AutomationResult(
          executionId: executionId,
          status: AutomationResultStatus.noPlan,
          reason: 'El planner LLM no produjo acciones verificables para el objetivo.',
        );
      }
      plan = generated;
    }

    if (plan.length > 1) {
      final outcome =
          await runPlan(plan, confirmed: confirmed, recordGoal: goal.text);
      return _resultFromPlan(executionId, outcome);
    }
    final outcome = await runTool(plan.single, confirmed: confirmed);
    return _resultFromTool(executionId, outcome);
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
        PolicyVerdict.allow => AutomationResultStatus.completed,
      };

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
