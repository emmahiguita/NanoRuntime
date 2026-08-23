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
import 'package:nanoai/features/automation/engine/goal_verifier.dart' show GoalExpectation;
import 'package:nanoai/features/automation/engine/nano_flow.dart'
    show FlowExecutionResult, NanoFlow, NanoFlowExecutor;

import '../domain/automation_policy.dart' show AgentAutomationMode, AutomationPolicy;

/// Coordinador del ciclo de ejecución. Inyecta sus dependencias (DIP).
class AutomationCoordinator {
  final ExperienceCache? _cache;
  final NanoFlowExecutor? _flowExecutor;
  final AgentToolDispatcher _dispatcher;

  /// Fuente del nivel de autonomía actual (puede cambiar en runtime vía
  /// settings). Se inyecta como función para no acoplar el coordinator a
  /// settings/Riverpod.
  final AgentAutomationMode Function() _mode;

  AutomationCoordinator({
    required AgentToolDispatcher dispatcher,
    required AgentAutomationMode Function() mode,
    ExperienceCache? cache,
    NanoFlowExecutor? flowExecutor,
  })  : _dispatcher = dispatcher,
        _mode = mode,
        _cache = cache,
        _flowExecutor = flowExecutor;

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
    final outcome = await _dispatcher.runPlanGuarded(plan, confirmed: confirmed);
    if (recordGoal != null) {
      if (outcome.completed) {
        _cache?.recordSuccess(recordGoal, plan);
      } else {
        _cache?.recordFailure(recordGoal);
      }
    }
    return outcome;
  }

  /// Ejecuta una herramienta suelta bajo gobernanza.
  Future<ToolOutcome> runTool(ToolCall call, {bool confirmed = false}) =>
      _dispatcher.runToolGuarded(call, confirmed: confirmed);

  /// Comando `@` determinista (autoría humana — confirmación implícita).
  Future<String> runCommand(String command) => _dispatcher.runCommand(command);

  /// Resetea el estado del turno del dispatcher (ciclo de vida de una ronda).
  void reset() => _dispatcher.resetTurn();
}
