import 'package:flutter/material.dart';

import '../../../engine/mcp/http_mcp_client.dart';
import '../../../engine/mcp/mcp_client_port.dart';
import '../../../engine/mcp/mcp_connection_registry.dart';
import '../../../engine/mcp/mcp_store_catalog.dart';
import '../../../engine/mcp/mcp_server_persistence.dart';
import '../../automation_visual_theme.dart';
import 'mcp_hot_injection_dialog.dart';

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
    final isRemoteTemplate = item.transport == McpTransportKind.streamableHttp;
    final stateColor = isConnected ? visual.success : visual.accent;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: visual.cardStart,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isConnected
              ? visual.success.withValues(alpha: 0.5)
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
                  color: stateColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  item.transport.name.toUpperCase(),
                  style: TextStyle(
                    color: stateColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item.author,
                  style: TextStyle(color: visual.textMuted, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (item.isVerified) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.verified_rounded,
                        size: 12,
                        color: Colors.blue,
                      ),
                      SizedBox(width: 3),
                      Text(
                        'OFICIAL',
                        style: TextStyle(
                          color: Colors.blue,
                          fontSize: 11,
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
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
                        fontSize: 12,
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
              Expanded(
                child: Text(
                  isConnected
                      ? 'CONECTADO Y ACTIVO'
                      : isRemoteTemplate
                      ? 'PLANTILLA LISTA PARA CONFIGURAR'
                      : 'NO CONECTADO',
                  style: TextStyle(
                    color: isConnected ? visual.success : visual.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              if (isConnected)
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    side: const BorderSide(color: Colors.redAccent),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    minimumSize: Size.zero,
                  ),
                  onPressed: onDisconnect,
                  child: const Text(
                    'Desconectar',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                )
              else
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: visual.accent,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    minimumSize: Size.zero,
                  ),
                  onPressed: onConnect,
                  child: Text(
                    isRemoteTemplate ? 'Configurar' : 'Conectar',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
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
  required McpServerPersistence persistence,
  required AutomationVisualPalette visual,
  required void Function(String message) onConnected,
}) async {
  if (item.transport == McpTransportKind.androidBinder) {
    // El cliente local ya fue creado con sus dependencias reales en el composition root.
    if (registry.client(item.id) == null) {
      onConnected(
        'El conector local de Nano no está registrado en esta sesión.',
      );
      return;
    }
    final snap = await registry.refreshTools();
    onConnected(
      '${item.name} conectado. ${snap.tools.length} herramientas activas.',
    );
    return;
  }

  final idController = TextEditingController(
    text: item.transport == McpTransportKind.streamableHttp
        ? 'mcp-server-${DateTime.now().millisecondsSinceEpoch}'
        : item.id,
  );
  final nameController = TextEditingController(text: item.name);
  final endpointController = TextEditingController(text: item.defaultEndpoint);
  final tokenController = TextEditingController();

  await showDialog<void>(
    context: context,
    builder: (ctx) {
      bool connecting = false;
      String? errorMsg;

      return StatefulBuilder(
        builder: (context, setDlgState) {
          return AlertDialog(
            backgroundColor: visual.isDark
                ? const Color(0xFF0E1726)
                : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
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
                    Text(
                      'Identificador único del servidor:',
                      style: TextStyle(color: visual.textMuted, fontSize: 12),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: idController,
                      style: TextStyle(
                        color: visual.text,
                        fontSize: 13,
                        fontFamily: 'monospace',
                      ),
                      decoration: const InputDecoration(
                        isDense: true,
                        hintText: 'calendar-mcp',
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Nombre para mostrar:',
                      style: TextStyle(color: visual.textMuted, fontSize: 12),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: nameController,
                      style: TextStyle(color: visual.text, fontSize: 13),
                      decoration: const InputDecoration(
                        isDense: true,
                        hintText: 'Mi calendario',
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Endpoint URL del servidor MCP:',
                      style: TextStyle(color: visual.textMuted, fontSize: 12),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: endpointController,
                      style: TextStyle(
                        color: visual.text,
                        fontSize: 13,
                        fontFamily: 'monospace',
                      ),
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        filled: true,
                        fillColor: visual.inputFill,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Token de autorización (opcional):',
                      style: TextStyle(color: visual.textMuted, fontSize: 12),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: tokenController,
                      obscureText: true,
                      style: TextStyle(color: visual.text, fontSize: 13),
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        filled: true,
                        fillColor: visual.inputFill,
                        hintText: 'Bearer token o API Key',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    if (errorMsg != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        errorMsg!,
                        style: const TextStyle(color: Colors.red, fontSize: 11),
                      ),
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

                        HttpMcpClient? client;
                        final serverId = idController.text.trim();
                        var saved = false;
                        try {
                          if (registry.client(serverId) != null) {
                            throw const FormatException(
                              'duplicate_mcp_server_id',
                            );
                          }
                          final descriptor = item.toDescriptor(
                            customServerId: serverId,
                            customDisplayName: nameController.text.trim(),
                            customEndpoint: endpointController.text.trim(),
                            credentialRef: persistence.credentialRefFor(
                              serverId,
                            ),
                          );
                          persistence.validateDescriptor(descriptor);
                          final token = tokenController.text.trim();
                          client = HttpMcpClient(
                            descriptor: descriptor,
                            credentialToken: token.isEmpty ? null : token,
                          );
                          final connResult = await client.connect();

                          if (!connResult.success) {
                            await client.disconnect();
                            setDlgState(() {
                              connecting = false;
                              errorMsg =
                                  connResult.message ??
                                  'No se pudo conectar con el endpoint';
                            });
                            return;
                          }

                          final registration = await registry.register(client);
                          if (registration.status ==
                              McpRegistrationStatus.duplicateRejected) {
                            throw const FormatException(
                              'duplicate_mcp_server_id',
                            );
                          }
                          await persistence.save(
                            descriptor,
                            credentialToken: token.isEmpty ? null : token,
                          );
                          saved = true;
                          final snap = await registry.refreshTools();
                          if (ctx.mounted) Navigator.of(ctx).pop();
                          final discoveryFailure = snap.failures
                              .where((failure) => failure.serverId == serverId)
                              .firstOrNull;
                          onConnected(
                            discoveryFailure == null
                                ? '${descriptor.displayName} conectado; ${snap.tools.values.where((tool) => tool.serverId == serverId).length} herramientas descubiertas.'
                                : 'Conectó, pero no pudo descubrir herramientas: ${discoveryFailure.reason}',
                          );
                        } catch (_) {
                          if (saved) {
                            try {
                              await persistence.remove(serverId);
                            } on Object {
                              // El error principal se conserva; no se oculta por un rollback fallido.
                            }
                          }
                          if (client != null &&
                              registry.client(serverId) == client) {
                            await registry.unregister(serverId);
                          } else {
                            await client?.disconnect();
                          }
                          setDlgState(() {
                            connecting = false;
                            errorMsg =
                                'No se pudo guardar la conexión. Verifica que el ID sea único y que la URL implemente Streamable HTTP.';
                          });
                        }
                      },
                child: connecting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Conectar Ahora'),
              ),
            ],
          );
        },
      );
    },
  ).whenComplete(() {
    idController.dispose();
    nameController.dispose();
    tokenController.clear();
    tokenController.dispose();
    endpointController.dispose();
  });
}

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
