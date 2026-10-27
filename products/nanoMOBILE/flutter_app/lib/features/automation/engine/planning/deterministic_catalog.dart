/// Catálogo determinista — flujos CONOCIDOS para objetivos comunes.
///
/// R0: el catálogo solo resuelve navegación claramente expresada. Mencionar
/// "Bluetooth" NO equivale a pedir abrirlo, y nunca equivale a activar/apagar
/// un switch.
library;

import 'package:nanoai/features/automation/engine/execution/agent_tool_dispatcher.dart'
    show ToolCall;
import 'package:nanoai/features/automation/engine/execution/goal_verifier.dart'
    show GoalExpectation;
part 'deterministic_navigation_definitions.dart';
part 'deterministic_flow_entries_0.dart';
part 'deterministic_flow_entries_1.dart';

class DeterministicFlow {
  final List<ToolCall> steps;
  final GoalExpectation? expectation;
  final bool outputProvesGoal;
  final List<String> requiredAny;
  final List<String> forbiddenAny;

  const DeterministicFlow({
    required this.steps,
    this.expectation,
    this.outputProvesGoal = false,
    this.requiredAny = const [],
    this.forbiddenAny = const [],
  });

  bool matches(String normalizedGoal, String keyword) {
    // Palabra completa (no subcadena): 'chat' NO debe capturar "chatgpt",
    // ni 'web' a "webtoon". Se tolera plural simple (archivo → archivos).
    if (!_containsWholeWord(normalizedGoal, keyword)) return false;
    // Mencionar una app en una pregunta no autoriza abrirla. Conserva el atajo exacto.
    // La intención operativa debe contener un término de apertura como palabra completa.
    final launchesApp = steps.any((step) => step.tool == 'launch_app');
    if (launchesApp &&
        normalizedGoal != keyword &&
        !_openTerms.any(
          (term) => RegExp(
            '(^|\\s)${RegExp.escape(term)}(\\s|\$)',
          ).hasMatch(normalizedGoal),
        )) {
      return false;
    }
    if (forbiddenAny.any(normalizedGoal.contains)) return false;
    if (requiredAny.isEmpty) return true;
    return requiredAny.any(normalizedGoal.contains);
  }
}

/// true si [keyword] aparece en [goal] delimitada por no-letras/no-dígitos
/// (Unicode-aware: \b de Dart no reconoce á/ñ). Admite plural "s"/"es".
bool _containsWholeWord(String goal, String keyword) {
  if (keyword.isEmpty) return false;
  return RegExp(
    r'(^|[^\p{L}\p{N}])' + RegExp.escape(keyword) + r'(?:s|es)?($|[^\p{L}\p{N}])',
    unicode: true,
  ).hasMatch(goal);
}

class DeterministicFlowCatalog {
  final Map<String, DeterministicFlow> _flows;
  const DeterministicFlowCatalog(this._flows);

  DeterministicFlow? forGoal(String goal) {
    final g = goal.trim().toLowerCase();
    for (final entry in _flows.entries) {
      if (entry.value.matches(g, entry.key)) return entry.value;
    }
    return null;
  }
}

// Un solo catálogo conserva orden, claves y acciones; las partes privadas no se duplican.
const defaultDeterministicCatalog = DeterministicFlowCatalog({
  ..._deterministicEntries0,
  ..._deterministicEntries1,
});
