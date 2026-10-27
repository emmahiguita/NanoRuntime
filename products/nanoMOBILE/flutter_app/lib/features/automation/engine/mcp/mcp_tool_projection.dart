/// Proyección fail-closed del catálogo MCP externo al contrato MCP ya existente
/// en Nano. Sólo clasifica; no registra ni ejecuta herramientas.
library;

import 'mcp_client_port.dart';
import 'mcp_tool.dart';
import 'mcp_local_tool_policy.dart';

class McpToolProjection {
  const McpToolProjection();

  McpTool toNanoTool(McpRemoteTool remote) {
    final category = McpLocalToolPolicy.category(remote);

    return McpTool(
      id: remote.qualifiedName,
      name: remote.name,
      category: category,
      description: remote.description,
      inputSchema: remote.inputSchema,
    );
  }

  Map<String, McpTool> projectAll(Iterable<McpRemoteTool> remoteTools) {
    final projected = <String, McpTool>{};
    for (final remote in remoteTools) {
      final tool = toNanoTool(remote);
      projected[tool.id] = tool;
    }
    return Map.unmodifiable(projected);
  }
}
