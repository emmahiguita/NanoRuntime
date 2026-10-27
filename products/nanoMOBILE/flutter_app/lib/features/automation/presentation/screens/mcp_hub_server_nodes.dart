part of 'mcp_skills_hub_screen.dart';

/// Presentación MCP: server nodes; no ejecuta herramientas.
extension _McpHubServerNodes on _McpSkillsHubScreenState {
  void _appendServers(
    AutomationVisualPalette visual,
    List<McpGraphNode> nodes,
    List<McpGraphEdge> edges,
  ) {
    final mcpRegistry = ref.watch(mcpConnectionRegistryProvider);
    final mcpTools = mcpRegistry.lastTools;
    final connectedServerIds = mcpRegistry.connectedServerIds;
    // 4. Mapeo Dinámico de Servidores MCP y sus Herramientas (Sin hardcoding)
    var nextServerY = 650.0;
    final serverList = mcpRegistry.servers.toList();
    for (int sIdx = 0; sIdx < serverList.length; sIdx++) {
      final server = serverList[sIdx];
      final connected = connectedServerIds.contains(server.id);
      final serverNodeId = 'mcp.server.${server.id}';
      final serverTools = mcpTools.values
          .where((t) => t.serverId == server.id)
          .toList();

      final serverOffset = Offset(650.0, nextServerY);

      nodes.add(
        McpGraphNode(
          id: serverNodeId,
          title: server.displayName,
          subtitle:
              '${serverTools.length} tools • ${server.transport.name.toUpperCase()}',
          type: McpGraphNodeType.mcp,
          offset: serverOffset,
          icon: Icons.devices_other_rounded,
          statusColor: connected ? visual.accent : visual.textMuted,
          metadata: {
            'server_id': server.id,
            'status': connected ? 'CONNECTED' : 'DISCONNECTED',
            'transport': server.transport.name,
            'endpoint': server.endpoint ?? 'in-process',
            'tools_count': serverTools.length,
          },
        ),
      );
      edges.add(
        McpGraphEdge(
          from: 'core',
          to: serverNodeId,
          color: connected ? visual.accent : visual.textMuted,
        ),
      );

      // Nodos hijos de herramientas correspondientes a este servidor
      for (int tIdx = 0; tIdx < serverTools.length; tIdx++) {
        final tool = serverTools[tIdx];
        final toolNodeId = 'mcp.tool.${tool.qualifiedName}';
        final toolOffset = serverOffset + Offset(260.0, tIdx * 82.0);

        nodes.add(
          McpGraphNode(
            id: toolNodeId,
            title: tool.name,
            subtitle: 'Tool MCP',
            type: McpGraphNodeType.tool,
            offset: toolOffset,
            icon: Icons.build_circle_outlined,
            statusColor: const Color(0xFF38BDF8),
            metadata: {
              'qualified_name': tool.qualifiedName,
              'server_id': tool.serverId,
              'description': tool.description,
              'schema': tool.inputSchema,
            },
          ),
        );
        edges.add(
          McpGraphEdge(
            from: serverNodeId,
            to: toolNodeId,
            color: const Color(0xFF38BDF8),
          ),
        );
      }
      nextServerY +=
          (serverTools.isEmpty ? 1 : serverTools.length) * 82.0 + 120;
    }
  }
}
