import 'mcp_client_port.dart';

/// Resultados de registro y descubrimiento; no implican ejecución de herramientas.
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
