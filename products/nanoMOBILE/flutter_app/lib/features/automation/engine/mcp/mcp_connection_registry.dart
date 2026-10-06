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
  McpDiscoverySnapshot? _lastSnapshot;
  Future<McpDiscoverySnapshot>? _discoveryInFlight;
  int _registryRevision = 0;

  Iterable<McpServerDescriptor> get servers =>
      List.unmodifiable(_clients.values.map((client) => client.descriptor));

  Set<String> get connectedServerIds => Set.unmodifiable(
    _clients.entries
        .where((entry) => entry.value.state == McpConnectionState.connected)
        .map((entry) => entry.key),
  );

  Map<String, McpRemoteTool> get lastTools => Map.unmodifiable(_lastTools);
  bool get hasDiscoverySnapshot => _lastSnapshot != null;

  McpClientPort? client(String serverId) => _clients[serverId];

  Future<McpRegistrationResult> register(
    McpClientPort client, {
    bool replaceExisting = false,
  }) async {
    final id = client.descriptor.id.trim();
    if (id.isEmpty) {
      throw ArgumentError.value(
        id,
        'client.descriptor.id',
        'No puede estar vacío.',
      );
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
    _registryRevision++;
    _lastSnapshot = null;
    if (exists) {
      _lastTools = Map.of(_lastTools)
        ..removeWhere((_, tool) => tool.serverId == id);
      if (!identical(previous, client)) {
        await previous?.disconnect();
      }
    }
    notifyListeners();
    return McpRegistrationResult(
      exists
          ? McpRegistrationStatus.replaced
          : McpRegistrationStatus.registered,
    );
  }

  Future<void> unregister(String serverId) async {
    final removed = _clients.remove(serverId);
    if (removed != null) _registryRevision++;
    _lastSnapshot = null;
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
  /// Reutiliza una consulta en vuelo para que chat, hub y restauración no dupliquen handshakes.
  Future<McpDiscoverySnapshot> refreshTools() {
    final running = _discoveryInFlight;
    if (running != null) return running;
    final operation = _discoverTools();
    _discoveryInFlight = operation;
    return operation.whenComplete(() {
      if (identical(_discoveryInFlight, operation)) _discoveryInFlight = null;
    });
  }

  /// Descubre una vez al inicio; los cambios explícitos siguen usando refreshTools.
  Future<McpDiscoverySnapshot> ensureToolsDiscovered() {
    final snapshot = _lastSnapshot;
    return snapshot == null ? refreshTools() : Future.value(snapshot);
  }

  Future<McpDiscoverySnapshot> _discoverTools() async {
    final revision = _registryRevision;
    final tools = <String, McpRemoteTool>{};
    final failures = <McpDiscoveryFailure>[];

    // Servidores independientes se descubren en paralelo para evitar sumar timeouts.
    final results = await Future.wait(
      _clients.entries
          .toList(growable: false)
          .map((entry) => _discoverClient(entry.key, entry.value)),
    );
    for (final result in results) {
      failures.addAll(result.failures);
      for (final tool in result.tools) {
        tools[tool.qualifiedName] = tool;
      }
    }

    // Una conexión agregada durante la consulta exige descubrir también su catálogo.
    if (revision != _registryRevision) return _discoverTools();
    _lastTools = Map.unmodifiable(tools);
    _lastSnapshot = McpDiscoverySnapshot(
      tools: _lastTools,
      failures: List.unmodifiable(failures),
      capturedAt: DateTime.now().toUtc(),
    );
    notifyListeners();
    return _lastSnapshot!;
  }

  Future<({List<McpRemoteTool> tools, List<McpDiscoveryFailure> failures})>
  _discoverClient(String serverId, McpClientPort client) async {
    try {
      if (client.state != McpConnectionState.connected) {
        final connection = await client.connect().timeout(
          const Duration(seconds: 10),
        );
        if (!connection.success) {
          return (
            tools: const <McpRemoteTool>[],
            failures: [
              McpDiscoveryFailure(
                serverId: serverId,
                reason: connection.message ?? connection.status.name,
              ),
            ],
          );
        }
      }
      final discovered = await client.listTools().timeout(
        const Duration(seconds: 10),
      );
      final tools = <McpRemoteTool>[];
      final failures = <McpDiscoveryFailure>[];
      for (final tool in discovered) {
        if (tool.serverId != serverId) {
          failures.add(
            McpDiscoveryFailure(
              serverId: serverId,
              reason: 'La herramienta declaró un servidor MCP distinto.',
            ),
          );
        } else {
          tools.add(tool);
        }
      }
      return (tools: tools, failures: failures);
    } catch (error) {
      return (
        tools: const <McpRemoteTool>[],
        failures: [
          McpDiscoveryFailure(
            serverId: serverId,
            reason: error is McpDiscoveryException
                ? error.message
                : 'discovery_exception:${error.runtimeType}',
          ),
        ],
      );
    }
  }
}
