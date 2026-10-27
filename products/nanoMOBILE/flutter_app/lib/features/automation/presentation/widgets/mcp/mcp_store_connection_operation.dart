part of 'mcp_store_components.dart';

/// Conecta, registra y persiste una única conexión; revierte solo sus cambios.
/// No ejecuta herramientas: el descubrimiento lee sus esquemas y errores.
Future<({bool saved, String message})> _connectStoreServer({
  required McpStoreItem item,
  required McpConnectionRegistry registry,
  required McpServerPersistence persistence,
  required String serverId,
  required String name,
  required String endpoint,
  required String token,
  required bool Function() isActive,
}) async {
  HttpMcpClient? client;
  var saved = false;
  try {
    if (registry.client(serverId) != null) {
      throw const FormatException('duplicate_mcp_server_id');
    }
    final descriptor = item.toDescriptor(
      customServerId: serverId,
      customDisplayName: name,
      customEndpoint: endpoint,
      credentialRef: persistence.credentialRefFor(serverId),
    );
    persistence.validateDescriptor(descriptor);
    client = HttpMcpClient(
      descriptor: descriptor,
      credentialToken: token.isEmpty ? null : token,
    );
    final connection = await client.connect();
    if (!connection.success) {
      await client.disconnect();
      return (
        saved: false,
        message: connection.message ?? 'No se pudo conectar.',
      );
    }
    if (!isActive()) throw StateError('connection_dialog_closed');
    final registration = await registry.register(client);
    if (registration.status == McpRegistrationStatus.duplicateRejected) {
      throw const FormatException('duplicate_mcp_server_id');
    }
    await persistence.save(
      descriptor,
      credentialToken: token.isEmpty ? null : token,
    );
    saved = true;
    final snapshot = await registry.refreshTools();
    final failure = snapshot.failures
        .where((f) => f.serverId == serverId)
        .firstOrNull;
    final count = snapshot.tools.values
        .where((t) => t.serverId == serverId)
        .length;
    return (
      saved: true,
      message: failure == null
          ? '${descriptor.displayName} conectado; $count herramientas descubiertas.'
          : 'Conexión guardada; catálogo no disponible: ${failure.reason}',
    );
  } catch (_) {
    if (saved) {
      try {
        await persistence.remove(serverId);
      } catch (_) {
        /* Conserva el fallo principal. */
      }
    }
    if (client != null && identical(registry.client(serverId), client)) {
      await registry.unregister(serverId);
    } else {
      await client?.disconnect();
    }
    return (
      saved: false,
      message:
          'No se pudo guardar la conexión. Revisa el ID único y la URL Streamable HTTP.',
    );
  }
}
