import 'package:flutter/material.dart';

import '../../../engine/mcp/http_mcp_client.dart';
import '../../../engine/mcp/mcp_client_port.dart';
import '../../../engine/mcp/mcp_connection_registry.dart';
import '../../automation_visual_theme.dart';

/// Modal dialog para inyección en caliente de servidores MCP remotos o locales.
Future<void> showMcpHotInjectionDialog({
  required BuildContext context,
  required McpConnectionRegistry registry,
  required AutomationVisualPalette visual,
  required void Function(String message) onInjected,
}) async {
  final idController = TextEditingController(text: 'mcp.custom.endpoint');
  final nameController = TextEditingController(text: 'Servidor MCP Externo');
  final urlController = TextEditingController(text: 'http://127.0.0.1:3000/sse');
  final tokenController = TextEditingController();
  const selectedTransport = McpTransportKind.sse;

  return showDialog<void>(
    context: context,
    builder: (ctx) {
      bool testing = false;
      String? testFeedback;
      bool? testPassed;

      return StatefulBuilder(
        builder: (context, setDlgState) {
          return AlertDialog(
            backgroundColor: visual.isDark ? const Color(0xFF0E1726) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
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
                    Text('Identificador único:', style: TextStyle(color: visual.textMuted, fontSize: 12)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: idController,
                      style: TextStyle(color: visual.text, fontSize: 13, fontFamily: 'monospace'),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: visual.inputFill,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text('Nombre descriptivo:', style: TextStyle(color: visual.textMuted, fontSize: 12)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: nameController,
                      style: TextStyle(color: visual.text, fontSize: 13),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: visual.inputFill,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text('Endpoint URL (HTTP o SSE):', style: TextStyle(color: visual.textMuted, fontSize: 12)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: urlController,
                      style: TextStyle(color: visual.text, fontSize: 13, fontFamily: 'monospace'),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: visual.inputFill,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text('Token Bearer / Clave API (opcional):', style: TextStyle(color: visual.textMuted, fontSize: 12)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: tokenController,
                      obscureText: true,
                      style: TextStyle(color: visual.text, fontSize: 13),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: visual.inputFill,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
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
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.network_check_rounded, size: 16),
                          label: const Text('Probar Conexión', style: TextStyle(fontSize: 12)),
                          onPressed: testing
                              ? null
                              : () async {
                                  setDlgState(() {
                                    testing = true;
                                    testFeedback = null;
                                  });
                                  try {
                                    final desc = McpServerDescriptor(
                                      id: idController.text.trim(),
                                      displayName: nameController.text.trim(),
                                      transport: selectedTransport,
                                      endpoint: urlController.text.trim(),
                                      credentialRef: tokenController.text.trim().isNotEmpty
                                          ? tokenController.text.trim()
                                          : null,
                                    );
                                    final testClient = HttpMcpClient(descriptor: desc);
                                    final res = await testClient.connect();
                                    if (res.success) {
                                      final tools = await testClient.listTools();
                                      setDlgState(() {
                                        testing = false;
                                        testPassed = true;
                                        testFeedback = 'Conectado (v${res.protocolVersion}). ${tools.length} tools descubiertas.';
                                      });
                                    } else {
                                      setDlgState(() {
                                        testing = false;
                                        testPassed = false;
                                        testFeedback = 'Fallo: ${res.message}';
                                      });
                                    }
                                  } catch (e) {
                                    setDlgState(() {
                                      testing = false;
                                      testPassed = false;
                                      testFeedback = 'Error: $e';
                                    });
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
                          color: (testPassed == true ? const Color(0xFF10B981) : Colors.red)
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: testPassed == true ? const Color(0xFF10B981) : Colors.red,
                          ),
                        ),
                        child: Text(
                          testFeedback!,
                          style: TextStyle(
                            color: testPassed == true ? const Color(0xFF10B981) : Colors.red,
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
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: visual.accent),
                onPressed: () async {
                  final desc = McpServerDescriptor(
                    id: idController.text.trim(),
                    displayName: nameController.text.trim(),
                    transport: selectedTransport,
                    endpoint: urlController.text.trim(),
                    credentialRef: tokenController.text.trim().isNotEmpty
                        ? tokenController.text.trim()
                        : null,
                  );
                  final client = HttpMcpClient(descriptor: desc);
                  await registry.register(client, replaceExisting: true);
                  final snap = await registry.refreshTools();

                  if (ctx.mounted) Navigator.of(ctx).pop();
                  onInjected('Servidor inyectado exitosamente. ${snap.tools.length} herramientas disponibles.');
                },
                child: const Text('Inyectar en Caliente'),
              ),
            ],
          );
        },
      );
    },
  );
}
