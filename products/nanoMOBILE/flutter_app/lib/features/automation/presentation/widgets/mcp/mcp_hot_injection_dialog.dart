import 'package:flutter/material.dart';

import '../../../engine/mcp/http_mcp_client.dart';
import '../../../engine/mcp/mcp_client_port.dart';
import '../../../engine/mcp/mcp_connection_registry.dart';
import '../../../engine/mcp/mcp_server_persistence.dart';
import '../../automation_visual_theme.dart';

/// Modal dialog para inyección en caliente de servidores MCP remotos o locales.
Future<void> showMcpHotInjectionDialog({
  required BuildContext context,
  required McpConnectionRegistry registry,
  required McpServerPersistence persistence,
  required AutomationVisualPalette visual,
  required void Function(String message) onInjected,
}) async {
  final idController = TextEditingController(text: 'mcp.custom.endpoint');
  final nameController = TextEditingController(text: 'Servidor MCP Externo');
  final urlController = TextEditingController();
  final tokenController = TextEditingController();
  const selectedTransport = McpTransportKind.streamableHttp;

  await showDialog<void>(
    context: context,
    builder: (ctx) {
      bool testing = false;
      String? testFeedback;
      bool? testPassed;

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
              'Inyectar Servidor MCP en Caliente',
              style: TextStyle(
                color: visual.text,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            content: SizedBox(
              width: 380,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Identificador único:',
                      style: TextStyle(color: visual.textMuted, fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    TextField(
                      controller: idController,
                      style: TextStyle(
                        color: visual.text,
                        fontSize: 13,
                        fontFamily: 'monospace',
                      ),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: visual.inputFill,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Nombre descriptivo:',
                      style: TextStyle(color: visual.textMuted, fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    TextField(
                      controller: nameController,
                      style: TextStyle(color: visual.text, fontSize: 13),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: visual.inputFill,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Endpoint URL (Streamable HTTP):',
                      style: TextStyle(color: visual.textMuted, fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    TextField(
                      controller: urlController,
                      style: TextStyle(
                        color: visual.text,
                        fontSize: 13,
                        fontFamily: 'monospace',
                      ),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: visual.inputFill,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Token Bearer / Clave API (opcional):',
                      style: TextStyle(color: visual.textMuted, fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    TextField(
                      controller: tokenController,
                      obscureText: true,
                      style: TextStyle(color: visual.text, fontSize: 13),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: visual.inputFill,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: visual.accent,
                            side: BorderSide(color: visual.accent),
                          ),
                          icon: testing
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(
                                  Icons.network_check_rounded,
                                  size: 16,
                                ),
                          label: const Text(
                            'Probar Conexión',
                            style: TextStyle(fontSize: 12),
                          ),
                          onPressed: testing
                              ? null
                              : () async {
                                  setDlgState(() {
                                    testing = true;
                                    testFeedback = null;
                                  });
                                  final serverId = idController.text.trim();
                                  final token = tokenController.text.trim();
                                  final desc = McpServerDescriptor(
                                    id: serverId,
                                    displayName: nameController.text.trim(),
                                    transport: selectedTransport,
                                    endpoint: urlController.text.trim(),
                                    credentialRef: persistence.credentialRefFor(
                                      serverId,
                                    ),
                                  );
                                  HttpMcpClient? testClient;
                                  try {
                                    persistence.validateDescriptor(desc);
                                    testClient = HttpMcpClient(
                                      descriptor: desc,
                                      credentialToken: token.isEmpty
                                          ? null
                                          : token,
                                    );
                                    final res = await testClient.connect();
                                    if (res.success) {
                                      final tools = await testClient
                                          .listTools();
                                      setDlgState(() {
                                        testing = false;
                                        testPassed = true;
                                        testFeedback =
                                            'Conectado (v${res.protocolVersion}). ${tools.length} herramientas descubiertas.';
                                      });
                                    } else {
                                      setDlgState(() {
                                        testing = false;
                                        testPassed = false;
                                        testFeedback = 'Fallo: ${res.message}';
                                      });
                                    }
                                  } catch (_) {
                                    setDlgState(() {
                                      testing = false;
                                      testPassed = false;
                                      testFeedback =
                                          'No se pudo probar la conexión MCP.';
                                    });
                                  } finally {
                                    await testClient?.disconnect();
                                  }
                                },
                        ),
                      ],
                    ),
                    if (testFeedback != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color:
                              (testPassed == true
                                      ? const Color(0xFF10B981)
                                      : Colors.red)
                                  .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: testPassed == true
                                ? const Color(0xFF10B981)
                                : Colors.red,
                          ),
                        ),
                        child: Text(
                          testFeedback!,
                          style: TextStyle(
                            color: testPassed == true
                                ? const Color(0xFF10B981)
                                : Colors.red,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: testing ? null : () => Navigator.of(ctx).pop(),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: visual.accent),
                onPressed: testing
                    ? null
                    : () async {
                        setDlgState(() {
                          testing = true;
                          testFeedback = null;
                        });
                        final serverId = idController.text.trim();
                        final token = tokenController.text.trim();
                        final desc = McpServerDescriptor(
                          id: serverId,
                          displayName: nameController.text.trim(),
                          transport: selectedTransport,
                          endpoint: urlController.text.trim(),
                          credentialRef: persistence.credentialRefFor(serverId),
                        );
                        HttpMcpClient? client;
                        var registered = false;
                        var saved = false;
                        try {
                          persistence.validateDescriptor(desc);
                          if (registry.client(serverId) != null) {
                            throw const FormatException(
                              'duplicate_mcp_server_id',
                            );
                          }
                          client = HttpMcpClient(
                            descriptor: desc,
                            credentialToken: token.isEmpty ? null : token,
                          );
                          final result = await client.connect();
                          if (!result.success) {
                            await client.disconnect();
                            setDlgState(() {
                              testing = false;
                              testPassed = false;
                              testFeedback =
                                  result.message ??
                                  'No se pudo conectar al servidor MCP.';
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
                          registered = true;
                          await persistence.save(
                            desc,
                            credentialToken: token.isEmpty ? null : token,
                          );
                          saved = true;
                          final snap = await registry.refreshTools();
                          if (ctx.mounted) Navigator.of(ctx).pop();
                          onInjected(
                            'Servidor conectado y guardado. ${snap.tools.length} herramientas activas.',
                          );
                        } catch (_) {
                          if (saved) {
                            try {
                              await persistence.remove(serverId);
                            } on Object {
                              // Un fallo al revertir no debe ocultar el motivo inicial.
                            }
                          }
                          if (registered) {
                            await registry.unregister(serverId);
                          } else {
                            await client?.disconnect();
                          }
                          if (ctx.mounted) {
                            setDlgState(() {
                              testing = false;
                              testPassed = false;
                              testFeedback =
                                  'No se pudo guardar o completar la conexión MCP.';
                            });
                          }
                        }
                      },
                child: Text(testing ? 'Conectando…' : 'Conectar y guardar'),
              ),
            ],
          );
        },
      );
    },
  ).whenComplete(() {
    tokenController.clear();
    tokenController.dispose();
    idController.dispose();
    nameController.dispose();
    urlController.dispose();
  });
}
