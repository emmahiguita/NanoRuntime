/// CandidateToolCallAdapter (A6) — convierte CandidateAction → ToolCall.
///
/// Usa SOLO el contrato canónico `args` (sin reintroducir selector/text/key).
/// Valida que `candidate.tool` existe en el ToolRegistry antes de producir un
/// ToolCall ejecutable. El `mustAppear`/`mustDisappear` (NanoSelector) no se
/// re-serializan en A6 (no hay DSL reversible público); documentado como
/// limitación.
library;

import '../../execution/action_verifier.dart' show ActionExpectation;
import '../../execution/agent_tool_dispatcher.dart' show ToolCall;
import '../../execution/tool_registry.dart' show ToolRegistry;
import 'candidate_action.dart';

/// Candidato con un tool que no existe en el registry: no ejecutable.
class CandidateToolUnknown implements Exception {
  final String tool;
  const CandidateToolUnknown(this.tool);

  @override
  String toString() => 'CandidateToolUnknown($tool)';
}

class CandidateToolCallAdapter {
  CandidateToolCallAdapter({ToolRegistry? registry})
    : _registry = registry ?? ToolRegistry.builtin;

  final ToolRegistry _registry;

  ToolCall toToolCall(CandidateAction candidate) {
    if (_registry.lookup(candidate.tool) == null) {
      throw CandidateToolUnknown(candidate.tool);
    }
    return ToolCall(
      tool: candidate.tool,
      args: candidate.args,
      expect: _expectToMap(candidate.expectation),
    );
  }

  Map<String, dynamic>? _expectToMap(ActionExpectation? e) {
    if (e == null) return null;
    return {
      if (e.expectedPackage != null) 'package': e.expectedPackage,
      if (e.expectedText != null) 'text': e.expectedText,
      if (e.forbiddenText != null) 'forbidden': e.forbiddenText,
    };
  }
}
