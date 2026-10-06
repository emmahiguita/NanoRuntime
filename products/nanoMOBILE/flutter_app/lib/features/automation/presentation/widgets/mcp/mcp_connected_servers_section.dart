import 'package:flutter/material.dart';

import '../../../engine/mcp/mcp_client_port.dart';
import '../../../engine/mcp/mcp_connection_registry.dart';
import '../../../engine/mcp/mcp_server_persistence.dart';
import '../../automation_visual_theme.dart';
import 'mcp_store_components.dart' show disconnectMcpStoreServer;

/// Muestra conexiones reales, también las creadas con IDs personalizados.
class McpConnectedServersSection extends StatelessWidget {
  const McpConnectedServersSection({
    super.key,
    required this.registry,
    required this.persistence,
    required this.visual,
  });

  final McpConnectionRegistry registry;
  final McpServerPersistence persistence;
  final AutomationVisualPalette visual;

  @override
  Widget build(BuildContext context) {
    final servers = registry.servers.toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Conexiones MCP reales (${servers.length})',
          style: TextStyle(color: visual.text, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        if (servers.isEmpty)
          Text(
            'Conecta un servidor Streamable HTTP para descubrir sus herramientas.',
            style: TextStyle(color: visual.textMuted, fontSize: 12),
          )
        else
          for (final server in servers)
            Card(
              color: visual.cardStart,
              child: ListTile(
                dense: true,
                title: Text(
                  server.displayName,
                  style: TextStyle(color: visual.text),
                ),
                subtitle: Text(
                  '${server.id} · ${_stateLabel(registry.client(server.id)?.state ?? McpConnectionState.disconnected)} · '
                  '${registry.lastTools.values.where((tool) => tool.serverId == server.id).length} tools',
                  style: TextStyle(color: visual.textMuted, fontSize: 12),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: server.transport == McpTransportKind.streamableHttp
                    ? IconButton(
                        tooltip: 'Desconectar y quitar',
                        icon: Icon(
                          Icons.link_off_rounded,
                          color: Theme.of(context).colorScheme.error,
                        ),
                        onPressed: () => disconnectMcpStoreServer(
                          context: context,
                          serverId: server.id,
                          serverName: server.displayName,
                          registry: registry,
                          persistence: persistence,
                        ),
                      )
                    : const Icon(Icons.phone_android_rounded, size: 18),
              ),
            ),
      ],
    );
  }

  /// Traduce los estados de conexión reales para que no se confundan con errores técnicos.
  String _stateLabel(McpConnectionState state) => switch (state) {
    McpConnectionState.connected => 'conectado',
    McpConnectionState.connecting => 'conectando',
    McpConnectionState.failed => 'falló',
    McpConnectionState.disconnected => 'desconectado',
  };
}
