import 'package:flutter/material.dart';

import '../../../engine/mcp/mcp_client_port.dart';
import '../../../engine/mcp/mcp_connection_registry.dart';
import '../../automation_visual_theme.dart';
import 'mcp_graph_components.dart';

/// Ejecuta una prueba en vivo contra una herramienta MCP y muestra los resultados.
Future<void> showMcpToolTestDialog({
  required BuildContext context,
  required McpGraphNode node,
  required McpConnectionRegistry registry,
  required AutomationVisualPalette visual,
}) async {
  final serverId = (node.metadata['server_id'] as String?) ?? 'device';
  final client = registry.client(serverId) ??
      registry.client('device') ??
      (registry.servers.isNotEmpty ? registry.client(registry.servers.first.id) : null);

  if (client == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Servidor MCP "$serverId" no se encuentra conectado.')),
    );
    return;
  }

  String toolName = node.title;
  if (node.type != McpGraphNodeType.tool) {
    toolName = 'diagnostics';
  }

  return showDialog<void>(
    context: context,
    builder: (dialogCtx) {
      return FutureBuilder<McpToolCallResult>(
        future: client.callTool(
          McpToolCall(
            serverId: client.descriptor.id,
            toolName: toolName,
            arguments: const {},
          ),
        ),
        builder: (context, snapshot) {
          final isDone = snapshot.connectionState == ConnectionState.done;
          final contentText = snapshot.data?.content
                  .map((c) => c.text ?? '')
                  .where((t) => t.isNotEmpty)
                  .join('\n') ??
              snapshot.data?.message ??
              'Sin respuesta devuelta por el servidor MCP';

          return AlertDialog(
            backgroundColor: visual.isDark ? const Color(0xFF0E1726) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            title: Row(
              children: [
                Icon(Icons.bolt_rounded, color: visual.accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Ejecución: $toolName',
                    style: TextStyle(
                      color: visual.text,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 380,
              child: isDone
                  ? snapshot.hasError
                      ? Text(
                          'Error: ${snapshot.error}',
                          style: const TextStyle(color: Colors.red),
                        )
                      : SingleChildScrollView(
                          child: SelectableText(
                            contentText,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 11,
                              height: 1.4,
                            ),
                          ),
                        )
                  : const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 12),
                        Text('Consultando herramienta MCP...'),
                      ],
                    ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogCtx).pop(),
                child: const Text('Cerrar'),
              ),
            ],
          );
        },
      );
    },
  );
}
