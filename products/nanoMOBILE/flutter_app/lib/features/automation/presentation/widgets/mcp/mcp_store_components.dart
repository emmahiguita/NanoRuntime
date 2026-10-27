import 'package:flutter/material.dart';

import '../../../engine/mcp/http_mcp_client.dart';
import '../../../engine/mcp/mcp_client_port.dart';
import '../../../engine/mcp/mcp_connection_registry.dart';
import '../../../engine/mcp/mcp_store_catalog.dart';
import '../../../engine/mcp/mcp_server_persistence.dart';
import '../../automation_visual_theme.dart';
import 'mcp_hot_injection_dialog.dart';

part 'mcp_store_item_card.dart';
part 'mcp_store_metadata.dart';
part 'mcp_store_connect.dart';
part 'mcp_store_connection_operation.dart';
part 'mcp_store_form.dart';

Future<void> disconnectMcpStoreServer({
  required BuildContext context,
  required String serverId,
  required String serverName,
  required McpConnectionRegistry registry,
  required McpServerPersistence persistence,
}) async {
  try {
    await persistence.remove(serverId);
    await registry.unregister(serverId);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Servidor $serverName desconectado.')),
      );
    }
  } catch (_) {
    await registry.unregister(serverId);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Servidor desconectado de esta sesión; no se pudo guardar la eliminación.',
          ),
        ),
      );
    }
  }
}

class McpHotInjectionBanner extends StatelessWidget {
  const McpHotInjectionBanner({
    super.key,
    required this.visual,
    required this.registry,
    required this.persistence,
    required this.onInjected,
  });

  final AutomationVisualPalette visual;
  final McpConnectionRegistry registry;
  final McpServerPersistence persistence;
  final ValueChanged<String> onInjected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            visual.accent.withValues(alpha: 0.18),
            visual.accent.withValues(alpha: 0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: visual.accent.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: visual.accent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.add_to_photos_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Inyección en Caliente (Hot Injection)',
                  style: TextStyle(
                    color: visual.text,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Conecta herramientas locales y servidores MCP remotos Streamable HTTP.',
                  style: TextStyle(color: visual.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: visual.accent,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => showMcpHotInjectionDialog(
              context: context,
              registry: registry,
              persistence: persistence,
              visual: visual,
              onInjected: onInjected,
            ),
            child: const Text(
              'Inyectar',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
