import 'package:flutter/material.dart';
import 'package:nanoai/core/widgets/feather_core_icon.dart';
import '../../../engine/mcp/mcp_client_port.dart';
import '../../../engine/mcp/mcp_connection_registry.dart';
import '../../../engine/mcp/mcp_local_tool_policy.dart';
import '../../../engine/mcp/mcp_tool.dart';
import 'mcp_tool_preparation.dart';

/// Catálogo observado, agrupado por servidor. Buscar o abrir no invoca herramientas.
class McpToolsBrowser extends StatefulWidget {
  const McpToolsBrowser({super.key, required this.registry});
  final McpConnectionRegistry registry;
  @override
  State<McpToolsBrowser> createState() => _McpToolsBrowserState();
}

class _McpToolsBrowserState extends State<McpToolsBrowser> {
  String _query = '';
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tools =
        widget.registry.lastTools.values
            .where(
              (t) => '${t.serverId} ${t.name} ${t.description}'
                  .toLowerCase()
                  .contains(_query),
            )
            .toList()
          ..sort((a, b) => a.qualifiedName.compareTo(b.qualifiedName));
    final rows = <Widget>[
      TextField(
        onChanged: (text) => setState(() => _query = text.trim().toLowerCase()),
        decoration: const InputDecoration(
          labelText: 'Buscar herramientas y servidores',
          prefixIcon: Icon(Icons.search_rounded),
        ),
      ),
      const SizedBox(height: 12),
      Text(
        '${tools.length} herramientas en el catálogo observado.',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      const SizedBox(height: 8),
      const Text(
        'El catálogo describe capacidades; una conexión no demuestra que una herramienta se haya ejecutado.',
      ),
    ];
    String? lastServer;
    for (final tool in tools) {
      if (lastServer != tool.serverId) {
        lastServer = tool.serverId;
        final client = widget.registry.client(tool.serverId);
        rows.add(
          Padding(
            padding: const EdgeInsets.only(top: 22, bottom: 8),
            child: Text(
              '${client?.descriptor.displayName ?? tool.serverId} · ${_stateLabel(client?.state)}',
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
        );
      }
      rows.add(
        Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            contentPadding: const EdgeInsets.all(12),
            leading: FeatherCoreIcon(
              type: _icon(tool.name),
              size: 38,
              framed: false,
            ),
            title: Text(
              tool.name,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tool.description.isEmpty
                        ? 'Sin descripción publicada.'
                        : tool.description,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    McpLocalToolPolicy.category(tool) == McpToolCategory.read
                        ? 'Lectura local reconocida'
                        : 'Requiere confirmación',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => showMcpToolPreparation(context, tool),
          ),
        ),
      );
    }
    if (tools.isEmpty) {
      rows.add(
        const Padding(
          padding: EdgeInsets.all(20),
          child: Text(
            'Sin herramientas para mostrar. Revisa las conexiones y actualiza el catálogo.',
          ),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: rows,
    );
  }

  /// Cada familia usa el símbolo Nano correspondiente a su función.
  FeatherCoreType _icon(String name) {
    if (name.contains('.fs.')) return FeatherCoreType.files;
    if (name.contains('.archive.')) return FeatherCoreType.documents;
    if (name.contains('.git.')) return FeatherCoreType.code;
    if (name.contains('.process.')) return FeatherCoreType.terminal;
    if (name.contains('observe') || name.contains('image')) {
      return FeatherCoreType.vision;
    }
    if (name.contains('diagnos')) return FeatherCoreType.system;
    return FeatherCoreType.network;
  }

  String _stateLabel(McpConnectionState? state) => switch (state) {
    McpConnectionState.connected => 'Conectado',
    McpConnectionState.connecting => 'Conectando',
    McpConnectionState.failed => 'Conexión fallida',
    _ => 'Desconectado',
  };
}
