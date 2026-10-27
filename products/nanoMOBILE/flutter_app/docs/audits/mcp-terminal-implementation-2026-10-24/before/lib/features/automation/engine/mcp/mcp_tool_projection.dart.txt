/// Proyección fail-closed del catálogo MCP externo al contrato MCP ya existente
/// en Nano. Sólo clasifica; no registra ni ejecuta herramientas.
library;

import 'mcp_client_port.dart';
import 'mcp_tool.dart';

class McpToolProjection {
  const McpToolProjection();

  McpTool toNanoTool(McpRemoteTool remote) {
    final annotations = remote.annotations;

    // MCP annotations son hints del servidor, no una autorización. Sólo una
    // tool declarada explícitamente read-only y no destructiva entra como read.
    // Todo lo demás degrada conservadoramente a externalWrite.
    final category = annotations.readOnlyHint && !annotations.destructiveHint
        ? McpToolCategory.read
        : McpToolCategory.externalWrite;

    return McpTool(
      id: remote.qualifiedName,
      name: remote.name,
      category: category,
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
