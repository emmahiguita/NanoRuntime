import '../../mcp/mcp_client_port.dart';
import '../../mcp/mcp_connection_registry.dart';

/// Presenta el estado ya conocido; listar nunca inicia conexiones remotas.
class McpCommandListFormatter {
  const McpCommandListFormatter(this.registry);

  final McpConnectionRegistry registry;

  /// Resume servidores en `@mcp list` y muestra herramientas en `@mcp list <id>`.
  String format(List<String> parts) {
    final filter = parts.length > 1 ? parts[1].toLowerCase() : null;
    final servers = registry.servers.where(
      (server) => filter == null || server.id.toLowerCase() == filter,
    );
    final selected = servers.toList(growable: false);
    if (selected.isEmpty) return 'No se encontró ese servidor MCP.';

    final activeCount = registry.connectedServerIds.length;
    final output = StringBuffer(
      'Estado MCP: $activeCount de ${registry.servers.length} servidores conectados.\n',
    );
    for (final server in selected) {
      final state =
          registry.client(server.id)?.state ?? McpConnectionState.disconnected;
      final tools = registry.lastTools.values
          .where((tool) => tool.serverId == server.id)
          .toList(growable: false);
      output.writeln(
        '• ${server.displayName} (${server.id}): ${_label(state)} · ${tools.length} herramientas conocidas',
      );
      if (filter != null) {
        for (final tool in tools) {
          output.writeln('  - ${tool.name}: ${_singleLine(tool.description)}');
        }
      }
    }
    if (filter == null && registry.lastTools.isEmpty) {
      output.write(
        'Aún no hay herramientas descubiertas. Conecta un servidor para consultarlas.',
      );
    } else if (filter != null &&
        registry.lastTools.values
            .where((tool) => tool.serverId == selected.first.id)
            .isEmpty) {
      output.write('No hay herramientas conocidas para este servidor.');
    }
    return output.toString().trim();
  }

  /// Evita que descripciones extensas o multilínea rompan el formato del chat.
  String _singleLine(String value) {
    final line = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    return line.length > 160 ? '${line.substring(0, 157)}…' : line;
  }

  /// Traduce los estados reales del cliente sin etiquetar como activo lo fallido.
  String _label(McpConnectionState state) => switch (state) {
    McpConnectionState.connected => 'conectado',
    McpConnectionState.connecting => 'conectando',
    McpConnectionState.failed => 'falló',
    McpConnectionState.disconnected => 'desconectado',
  };
}
