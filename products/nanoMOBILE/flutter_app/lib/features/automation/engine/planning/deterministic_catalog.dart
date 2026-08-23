/// Catálogo determinista — flujos CONOCIDOS para objetivos comunes.
///
/// Permite que la automatización funcione REALMENTE SIN el modelo LLM: para un
/// objetivo conocido (p.ej. "abrir Bluetooth") se ejecuta un flujo verificado
/// determinista con su expectativa de objetivo, bajo la misma gobernanza, sin
/// el planner. Es la vía "el LLM no hace el trabajo que un flujo puede hacer".
///
/// El flujo NO es inventado: se re-verifica en replay (GoalVerifier con la
/// [expectation]). Si la pantalla real no coincide → `failed` (honesto), no
/// éxito falso.
library;

import 'package:nanoai/features/automation/engine/execution/agent_tool_dispatcher.dart'
    show ToolCall;
import 'package:nanoai/features/automation/engine/execution/goal_verifier.dart'
    show GoalExpectation;

class DeterministicFlow {
  final List<ToolCall> steps;
  final GoalExpectation? expectation;

  const DeterministicFlow({required this.steps, this.expectation});
}

/// Catálogo de flujos deterministas (objetivo normalizado → flujo).
class DeterministicFlowCatalog {
  final Map<String, DeterministicFlow> _flows;
  const DeterministicFlowCatalog(this._flows);

  /// Devuelve un determinista para el objetivo (coincidencia inexacta: contiene
  /// la palabra clave o el objetivo es cercano). null = no conocido.
  DeterministicFlow? forGoal(String goal) {
    final g = goal.toLowerCase();
    for (final entry in _flows.entries) {
      if (g.contains(entry.key)) return entry.value;
    }
    return null;
  }
}

/// Flujos por defecto (objetivos comunes). Pasos REALES (tap en texto visible,
/// back, etc.) + expectativa de objetivo para verificar en replay.
const DeterministicFlowCatalog defaultDeterministicCatalog =
    DeterministicFlowCatalog({
  'bluetooth': DeterministicFlow(
    steps: [ToolCall(tool: 'tap', selector: 'text=Bluetooth')],
    expectation: GoalExpectation(visibleText: 'Bluetooth'),
  ),
  'wifi': DeterministicFlow(
    steps: [ToolCall(tool: 'tap', selector: 'text=Wi-Fi')],
    expectation: GoalExpectation(visibleText: 'Wi-Fi'),
  ),
  'ajustes': DeterministicFlow(
    steps: [ToolCall(tool: 'tap', selector: 'text=Ajustes')],
    expectation: GoalExpectation(visibleText: 'Ajustes'),
  ),
  'chrome': DeterministicFlow(
    steps: [ToolCall(tool: 'tap', selector: 'text=Chrome')],
    expectation: GoalExpectation(visibleText: 'Chrome'),
  ),
  'volver': DeterministicFlow(
    steps: [ToolCall(tool: 'back')],
  ),
});
