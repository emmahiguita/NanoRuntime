part of 'mcp_store_components.dart';

/// Tienda MCP: connect; conserva validación y almacenamiento seguro.
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
    try {
      final snap = await registry.refreshTools();
      if (!context.mounted) return;
      final failure = snap.failures
          .where((f) => f.serverId == item.id)
          .firstOrNull;
      final connected =
          registry.client(item.id)?.state == McpConnectionState.connected;
      final count = snap.tools.values
          .where((t) => t.serverId == item.id)
          .length;
      onConnected(
        failure != null
            ? '${item.name}: ${failure.reason}'
            : !connected
            ? '${item.name}: no conectado.'
            : '${item.name} conectado. $count herramientas descubiertas.',
      );
    } catch (_) {
      if (context.mounted) {
        onConnected('${item.name}: no se pudo consultar el conector local.');
      }
    }
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

  final ownerContext = context;
  bool connecting = false;
  String? errorMsg;
  await showDialog<void>(
    context: context,
    builder: (ctx) {
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
            content: _mcpConnectionForm(
              visual,
              idController,
              nameController,
              endpointController,
              tokenController,
              errorMsg,
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

                        final outcome = await _connectStoreServer(
                          item: item,
                          registry: registry,
                          persistence: persistence,
                          serverId: idController.text.trim(),
                          name: nameController.text.trim(),
                          endpoint: endpointController.text.trim(),
                          token: tokenController.text.trim(),
                          isActive: () => ctx.mounted,
                        );
                        if (!ctx.mounted) return;
                        if (outcome.saved) {
                          Navigator.of(ctx).pop();
                          if (ownerContext.mounted) {
                            onConnected(outcome.message);
                          }
                        } else {
                          setDlgState(() {
                            connecting = false;
                            errorMsg = outcome.message;
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
