import 'package:flutter/material.dart';

import '../../../engine/mcp/http_mcp_client.dart';
import '../../../engine/mcp/local_device_mcp_client.dart';
import '../../../engine/mcp/mcp_client_port.dart';
import '../../../engine/mcp/mcp_connection_registry.dart';
import '../../../engine/mcp/mcp_store_catalog.dart';
import '../../../engine/system/installed_app_catalog.dart';
import '../../automation_visual_theme.dart';

/// Tarjeta visual para un servidor MCP o Skill disponible en la tienda.
class McpStoreItemCard extends StatelessWidget {
  const McpStoreItemCard({
    super.key,
    required this.item,
    required this.visual,
    required this.isConnected,
    required this.onConnect,
    required this.onDisconnect,
  });

  final McpStoreItem item;
  final AutomationVisualPalette visual;
  final bool isConnected;
  final VoidCallback onConnect;
  final VoidCallback onDisconnect;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: visual.cardStart,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isConnected
              ? const Color(0xFF10B981).withValues(alpha: 0.5)
              : visual.cardBorder,
          width: isConnected ? 1.2 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: visual.shadow,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: (isConnected ? const Color(0xFF10B981) : const Color(0xFF8B5CF6))
                      .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  item.transport.name.toUpperCase(),
                  style: TextStyle(
                    color: isConnected ? const Color(0xFF10B981) : const Color(0xFF8B5CF6),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item.author,
                  style: TextStyle(color: visual.textMuted, fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (item.isVerified) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.verified_rounded, size: 12, color: Colors.blue),
                      SizedBox(width: 3),
                      Text(
                        'OFICIAL',
                        style: TextStyle(
                          color: Colors.blue,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(
            item.name,
            style: TextStyle(
              color: visual.text,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            item.description,
            style: TextStyle(
              color: visual.textMuted,
              fontSize: 12,
              height: 1.35,
            ),
          ),
          if (item.sampleTools.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (final tool in item.sampleTools)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: visual.inputFill,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: visual.cardBorder),
                    ),
                    child: Text(
                      tool,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        color: visual.text,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                isConnected ? 'CONECTADO Y ACTIVO' : 'NO CONECTADO',
                style: TextStyle(
                  color: isConnected ? const Color(0xFF10B981) : visual.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              if (isConnected)
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    side: const BorderSide(color: Colors.redAccent),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    minimumSize: Size.zero,
                  ),
                  onPressed: onDisconnect,
                  child: const Text('Desconectar', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                )
              else
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: visual.accent,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    minimumSize: Size.zero,
                  ),
                  onPressed: onConnect,
                  child: const Text('Conectar', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Diálogo para conectar un servidor de la tienda con endpoint o tokens opcionales.
Future<void> showMcpStoreConnectDialog({
  required BuildContext context,
  required McpStoreItem item,
  required McpConnectionRegistry registry,
  required InstalledAppCatalog? appCatalog,
  required AutomationVisualPalette visual,
  required void Function(String message) onConnected,
}) async {
  if (item.transport == McpTransportKind.androidBinder) {
    final client = LocalDeviceMcpClient(appCatalog: appCatalog);
    await registry.register(client, replaceExisting: true);
    final snap = await registry.refreshTools();
    onConnected('${item.name} conectado. ${snap.tools.length} herramientas activas.');
    return;
  }

  final endpointController = TextEditingController(text: item.defaultEndpoint);
  final tokenController = TextEditingController();

  return showDialog<void>(
    context: context,
    builder: (ctx) {
      bool connecting = false;
      String? errorMsg;

      return StatefulBuilder(
        builder: (context, setDlgState) {
          return AlertDialog(
            backgroundColor: visual.isDark ? const Color(0xFF0E1726) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            title: Text(
              'Conectar ${item.name}',
              style: TextStyle(
                color: visual.text,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            content: SizedBox(
              width: 360,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Endpoint URL del servidor MCP:', style: TextStyle(color: visual.textMuted, fontSize: 12)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: endpointController,
                      style: TextStyle(color: visual.text, fontSize: 13, fontFamily: 'monospace'),
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        filled: true,
                        fillColor: visual.inputFill,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text('Token de autorización (opcional):', style: TextStyle(color: visual.textMuted, fontSize: 12)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: tokenController,
                      obscureText: true,
                      style: TextStyle(color: visual.text, fontSize: 13),
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        filled: true,
                        fillColor: visual.inputFill,
                        hintText: 'Bearer token o API Key',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    if (errorMsg != null) ...[
                      const SizedBox(height: 10),
                      Text(errorMsg!, style: const TextStyle(color: Colors.red, fontSize: 11)),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: connecting ? null : () => Navigator.of(ctx).pop(),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: visual.accent),
                onPressed: connecting
                    ? null
                    : () async {
                        setDlgState(() {
                          connecting = true;
                          errorMsg = null;
                        });

                        try {
                          final descriptor = item.toDescriptor(
                            customEndpoint: endpointController.text.trim(),
                            token: tokenController.text.trim().isNotEmpty ? tokenController.text.trim() : null,
                          );
                          final client = HttpMcpClient(descriptor: descriptor);
                          final connResult = await client.connect();

                          if (!connResult.success) {
                            setDlgState(() {
                              connecting = false;
                              errorMsg = connResult.message ?? 'No se pudo conectar con el endpoint';
                            });
                            return;
                          }

                          await registry.register(client, replaceExisting: true);
                          final snap = await registry.refreshTools();
                          if (ctx.mounted) Navigator.of(ctx).pop();
                          onConnected('${item.name} conectado. ${snap.tools.length} herramientas disponibles.');
                        } catch (e) {
                          setDlgState(() {
                            connecting = false;
                            errorMsg = 'Excepción de red: $e';
                          });
                        }
                      },
                child: connecting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Conectar Ahora'),
              ),
            ],
          );
        },
      );
    },
  );
}
