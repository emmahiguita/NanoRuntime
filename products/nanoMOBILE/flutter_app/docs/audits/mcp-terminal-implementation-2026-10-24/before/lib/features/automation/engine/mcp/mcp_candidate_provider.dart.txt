/// McpCandidateProvider (A14.2) — fuente de candidatos MCP read-only.
///
/// Produce CandidateAction grounded para MCP tools read/device que el goal
/// menciona. NO expone externalWrite/privileged (requieren governance/backend
/// explícito). El registry arranca vacío (backend MCP futuro); el contrato y la
/// integración al pipeline Candidate-First quedan listos.
library;

import '../planning/candidates/candidate_action.dart';
import '../planning/candidates/candidate_provider.dart';
import 'mcp_tool.dart';
import 'mcp_tool_adapter.dart';
import 'mcp_tool_registry.dart';

class McpCandidateProvider implements CandidateProvider {
  McpCandidateProvider(this._registry, this._adapter);

  final McpToolRegistry _registry;
  final McpToolAdapter _adapter;

  @override
  String get id => 'mcp';

  @override
  Future<List<CandidateAction>> provide(CandidateRequest request) async {
    final goal = request.goal.trim().toLowerCase();
    final candidates = <CandidateAction>[];
    for (final tool in _registry.all) {
      // Solo read/device se exponen como candidates; externalWrite/privileged
      // requieren governance explícito (nunca candidatos automáticos).
      if (tool.category == McpToolCategory.externalWrite ||
          tool.category == McpToolCategory.privileged) {
        continue;
      }
      final matches =
          goal.contains(tool.name.toLowerCase()) ||
          goal.contains(tool.id.toLowerCase());
      if (matches) {
        candidates.add(_adapter.adapt(tool, const {}));
      }
    }
    return candidates;
  }
}
