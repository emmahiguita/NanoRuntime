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
import 'package:nanoai/features/automation/engine/experience_cache.dart' show ExperienceCache;
import 'package:nanoai/features/automation/engine/goal_verifier.dart'
    show GoalExpectation, GoalStatus;
import 'package:nanoai/features/automation/engine/nano_flow.dart'
    show FlowExecutionResult, NanoFlow, NanoFlowExecutor;

import '../domain/automation_policy.dart' show AgentAutomationMode, AutomationPolicy;
import '../engine/tool_registry.dart' show PolicyVerdict;
import '../ledger/action_ledger.dart' show ActionLedger;
import '../ledger/automation_trace.dart' show AutomationTrace, AutomationTraceStatus;

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

  AutomationCoordinator({
    required AgentToolDispatcher dispatcher,
    required AgentAutomationMode Function() mode,
    ExperienceCache? cache,
    NanoFlowExecutor? flowExecutor,
    ActionLedger? ledger,
  })  : _dispatcher = dispatcher,
        _mode = mode,
        _cache = cache,
        _flowExecutor = flowExecutor,
        _ledger = ledger;

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

  // ── Trazas (ledger) ───────────────────────────────────────────────────────

  AutomationTraceStatus _statusFromFlow(FlowExecutionResult r) {
    if (r.plan.pauseIndex != null) return AutomationTraceStatus.paused;
    if (!r.completed) return AutomationTraceStatus.failed;
    return r.goal.status == GoalStatus.satisfied
        ? AutomationTraceStatus.completed
        : AutomationTraceStatus.completedUnverified;
  }

  AutomationTraceStatus _statusFromPlan(PlanOutcome o) {
    if (o.pauseIndex != null) return AutomationTraceStatus.paused;
    if (!o.completed) return AutomationTraceStatus.failed;
    return AutomationTraceStatus.completed;
  }

  AutomationTraceStatus _statusFromTool(ToolOutcome o) => switch (o.verdict) {
        PolicyVerdict.needsConfirmation => AutomationTraceStatus.paused,
        PolicyVerdict.denied => AutomationTraceStatus.denied,
        PolicyVerdict.allow => AutomationTraceStatus.completed,
      };

  void _record({
    required String goal,
    required AutomationTraceStatus status,
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
