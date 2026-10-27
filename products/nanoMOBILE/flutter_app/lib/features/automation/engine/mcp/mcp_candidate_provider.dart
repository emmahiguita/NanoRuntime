/// McpCandidateProvider (A14.2) — fuente de candidatos MCP read-only.
///
/// Produce CandidateAction grounded para MCP tools read/device que el goal
/// menciona. NO expone externalWrite/privileged (requieren governance/backend
/// explícito). Usa nombres reales y argumentos observados en la solicitud.
library;

import '../planning/candidates/candidate_action.dart';
import '../planning/candidates/candidate_provider.dart';
import 'mcp_tool.dart';
import 'mcp_candidate_arguments.dart';
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
    final candidates = <CandidateAction>[];
    for (final tool in _registry.all) {
      // Solo read/device se exponen como candidates; externalWrite/privileged
      // requieren governance explícito (nunca candidatos automáticos).
      if (tool.category == McpToolCategory.externalWrite ||
          tool.category == McpToolCategory.privileged) {
        continue;
      }
      if (McpCandidateArguments.matches(tool, request.goal)) {
        final args = McpCandidateArguments.extract(tool, request.goal);
        candidates.add(_adapter.adapt(tool, args));
      }
    }
    return candidates;
  }
}
