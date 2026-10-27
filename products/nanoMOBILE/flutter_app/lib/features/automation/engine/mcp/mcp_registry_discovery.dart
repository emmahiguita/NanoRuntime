part of 'mcp_connection_registry.dart';

/// Descubre clientes en paralelo y publica una instantánea con fallos explícitos.
extension _McpRegistryDiscovery on McpConnectionRegistry {
  Future<McpDiscoverySnapshot> _discoverTools() async {
    if (_closed) throw StateError("Registro MCP cerrado");
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
    if (_closed) throw StateError("Registro MCP cerrado");
    if (revision != _registryRevision) return _discoverTools();
    _lastTools = Map.unmodifiable(tools);
    _lastSnapshot = McpDiscoverySnapshot(
      tools: _lastTools,
      failures: List.unmodifiable(failures),
      capturedAt: DateTime.now().toUtc(),
    );
    _publish();
    return _lastSnapshot!;
  }

  Future<({List<McpRemoteTool> tools, List<McpDiscoveryFailure> failures})>
  _discoverClient(String serverId, McpClientPort client) async {
    try {
      if (client.state != McpConnectionState.connected) {
        final connection = await client.connect().timeout(
          const Duration(seconds: 30),
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
        const Duration(seconds: 35),
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
