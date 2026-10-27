import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../engine/mcp/mcp_connection_registry.dart';
import '../../automation_visual_theme.dart';
import 'mcp_graph_components.dart';

/// Inspecciona el catálogo sin ejecutar acciones ni sustituir servidores.
/// La ejecución sigue pasando por el agente y su política de autorización.
/// Se conserva el nombre público para mantener los consumidores del grafo.
Future<void> showMcpToolTestDialog({
  required BuildContext context,
  required McpGraphNode node,
  required McpConnectionRegistry registry,
  required AutomationVisualPalette visual,
}) async {
  final serverId = node.metadata['server_id'] as String?;
  final tools = registry.lastTools.values.where(
    (tool) => tool.serverId == serverId && tool.name == node.title,
  );
  final tool = tools.isEmpty ? null : tools.first;
  final client = serverId == null ? null : registry.client(serverId);
  // Datos observados del catálogo: una ausencia nunca activa otro servidor.
  final details = tool == null
      ? 'Servidor: ${serverId ?? "sin identificar"}\n'
            'Estado: ${client?.state.name ?? "no registrado"}\n'
            'No hay una herramienta identificada para este nodo.'
      : 'Servidor: ${tool.serverId}\n'
            'Herramienta: ${tool.name}\n'
            'Estado: ${client?.state.name ?? "no registrado"}\n\n'
            '${tool.description}\n\n'
            'Argumentos requeridos y opcionales:\n'
            '${const JsonEncoder.withIndent("  ").convert(tool.inputSchema)}\n\n'
            'Las anotaciones del servidor no conceden autorización. '
            'Solicita la ejecución desde el agente para aplicar sus controles.';
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: visual.isDark ? const Color(0xFF0E1726) : Colors.white,
      title: Text(
        'Información de herramienta',
        style: TextStyle(color: visual.text),
      ),
      content: SizedBox(
        width: 380,
        child: SingleChildScrollView(
          child: SelectableText(
            details,
            style: TextStyle(color: visual.text, height: 1.45),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Cerrar'),
        ),
      ],
    ),
  );
}
