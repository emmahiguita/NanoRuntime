/// Rehydrates saved remote MCP connections into the Automation registry.
library;

import 'dart:developer' as developer;

import 'mcp_client_port.dart';
import 'mcp_connection_registry.dart';
import 'mcp_server_persistence.dart';

typedef McpPersistedClientFactory =
    McpClientPort Function(McpPersistedServerConfiguration configuration);

final class McpRestoreReport {
  const McpRestoreReport({
    required this.restoredServerIds,
    required this.missingCredentialIds,
    required this.failedServerIds,
  });

  final List<String> restoredServerIds;
  final List<String> missingCredentialIds;
  final List<String> failedServerIds;
}

Future<McpRestoreReport> restorePersistedMcpConnections({
  required McpConnectionRegistry registry,
  required McpServerPersistence persistence,
  required McpPersistedClientFactory createClient,
  bool Function()? isActive,
}) async {
  final restored = <String>[];
  final missingCredentials = <String>[];
  final failed = <String>[];
  final List<McpPersistedServerConfiguration> configurations;
  try {
    configurations = await persistence.load();
  } catch (error) {
    developer.log(
      'MCP restore could not load configuration error=${error.runtimeType}',
      name: 'nano.mcp',
      level: 1000,
    );
    return const McpRestoreReport(
      restoredServerIds: [],
      missingCredentialIds: [],
      failedServerIds: [],
    );
  }

  for (final configuration in configurations) {
    if (isActive?.call() == false) break;
    final id = configuration.descriptor.id;
    if (configuration.missingCredential) {
      missingCredentials.add(id);
      continue;
    }

    McpClientPort? client;
    try {
      client = createClient(configuration);
      final result = await client.connect().timeout(
        const Duration(seconds: 12),
      );
      if (!result.success) {
        failed.add(id);
        await _safeDisconnect(client);
        continue;
      }
      if (isActive?.call() == false) {
        await _safeDisconnect(client);
        break;
      }
      await registry.register(client, replaceExisting: true);
      restored.add(id);
    } catch (_) {
      failed.add(id);
      await _safeDisconnect(client);
    }
  }

  if (isActive?.call() != false) {
    try {
      await registry.refreshTools();
    } catch (error) {
      developer.log(
        'MCP restore discovery failed error=${error.runtimeType}',
        name: 'nano.mcp',
        level: 1000,
      );
    }
  }
  if (missingCredentials.isNotEmpty || failed.isNotEmpty) {
    developer.log(
      'MCP restore incomplete: missing_credentials=${missingCredentials.length} '
      'failed=${failed.length}',
      name: 'nano.mcp',
      level: 900,
    );
  }
  return McpRestoreReport(
    restoredServerIds: List.unmodifiable(restored),
    missingCredentialIds: List.unmodifiable(missingCredentials),
    failedServerIds: List.unmodifiable(failed),
  );
}

Future<void> _safeDisconnect(McpClientPort? client) async {
  if (client == null) return;
  try {
    await client.disconnect();
  } catch (_) {
    // A failed remote server must not block restoration of other servers.
  }
}
