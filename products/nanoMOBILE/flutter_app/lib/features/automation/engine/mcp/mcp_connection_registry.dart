/// Runtime registry de conexiones MCP.
///
/// Responsabilidad limitada: registrar clientes y descubrir su catálogo.
/// NO ejecuta herramientas. Esto evita crear un bypass paralelo al
/// PolicyEngine/ToolHandler de Nano.
library;

import 'package:flutter/foundation.dart';

import 'mcp_client_port.dart';

enum McpRegistrationStatus { registered, replaced, duplicateRejected }

class McpRegistrationResult {
  const McpRegistrationResult(this.status, {this.message});

  final McpRegistrationStatus status;
  final String? message;
}

class McpDiscoveryFailure {
  const McpDiscoveryFailure({required this.serverId, required this.reason});

  final String serverId;
  final String reason;
}

class McpDiscoverySnapshot {
  const McpDiscoverySnapshot({
    required this.tools,
    required this.failures,
    required this.capturedAt,
  });

  final Map<String, McpRemoteTool> tools;
  final List<McpDiscoveryFailure> failures;
  final DateTime capturedAt;

  McpRemoteTool? lookup(String qualifiedName) => tools[qualifiedName];
}

class McpConnectionRegistry extends ChangeNotifier {
  final Map<String, McpClientPort> _clients = {};
  Map<String, McpRemoteTool> _lastTools = const {};

  Iterable<McpServerDescriptor> get servers =>
      List.unmodifiable(_clients.values.map((client) => client.descriptor));

  Map<String, McpRemoteTool> get lastTools => Map.unmodifiable(_lastTools);

  McpClientPort? client(String serverId) => _clients[serverId];

  Future<McpRegistrationResult> register(
    McpClientPort client, {
    bool replaceExisting = false,
  }) async {
    final id = client.descriptor.id.trim();
    if (id.isEmpty) {
      throw ArgumentError.value(id, 'client.descriptor.id', 'No puede estar vacío.');
    }

    final exists = _clients.containsKey(id);
    if (exists && !replaceExisting) {
      return McpRegistrationResult(
        McpRegistrationStatus.duplicateRejected,
        message: 'Ya existe un servidor MCP registrado con id $id.',
      );
    }

    final previous = _clients[id];
    _clients[id] = client;
    if (exists) {
      _lastTools = Map.of(_lastTools)
        ..removeWhere((_, tool) => tool.serverId == id);
      if (!identical(previous, client)) {
        await previous?.disconnect();
      }
    }
    notifyListeners();
    return McpRegistrationResult(
      exists ? McpRegistrationStatus.replaced : McpRegistrationStatus.registered,
    );
  }

  Future<void> unregister(String serverId) async {
    final removed = _clients.remove(serverId);
    _lastTools = Map.of(_lastTools)
      ..removeWhere((_, tool) => tool.serverId == serverId);
    if (removed != null) {
      await removed.disconnect();
    }
    notifyListeners();
  }

  /// Descubre catálogos de todos los servidores disponibles.
  ///
  /// Un servidor caído no borra el catálogo de los demás ni genera un éxito
  /// falso. El fallo queda explícito en [McpDiscoverySnapshot.failures].
  Future<McpDiscoverySnapshot> refreshTools() async {
    final tools = <String, McpRemoteTool>{};
    final failures = <McpDiscoveryFailure>[];

    for (final entry in _clients.entries) {
      final serverId = entry.key;
      final client = entry.value;
      try {
        if (client.state != McpConnectionState.connected) {
          final connection = await client
              .connect()
              .timeout(const Duration(seconds: 10));
          if (!connection.success) {
            failures.add(
              McpDiscoveryFailure(
                serverId: serverId,
                reason: connection.message ?? connection.status.name,
              ),
            );
            continue;
          }
        }

        final discovered = await client
            .listTools()
            .timeout(const Duration(seconds: 10));
        for (final tool in discovered) {
          if (tool.serverId != serverId) {
            failures.add(
              McpDiscoveryFailure(
                serverId: serverId,
                reason:
                    'Tool ${tool.name} declaró serverId=${tool.serverId}; se esperaba $serverId.',
              ),
            );
            continue;
          }
          tools[tool.qualifiedName] = tool;
        }
      } catch (error) {
        failures.add(
          McpDiscoveryFailure(
            serverId: serverId,
            reason: 'discovery_exception:${error.runtimeType}',
          ),
        );
      }
    }

    _lastTools = Map.unmodifiable(tools);
    notifyListeners();
    return McpDiscoverySnapshot(
      tools: _lastTools,
      failures: List.unmodifiable(failures),
      capturedAt: DateTime.now().toUtc(),
    );
  }
}
