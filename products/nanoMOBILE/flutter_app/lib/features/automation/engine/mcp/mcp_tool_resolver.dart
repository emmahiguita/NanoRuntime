import 'mcp_client_port.dart';
import 'mcp_connection_registry.dart';

/// QUÉ HACE:
/// Resuelve nombres calificados de herramientas MCP contra servidores y catálogos.
///
/// CÓMO FUNCIONA:
/// Analiza formatos de slash (serverId/toolName) y punto (serverId.toolName),
/// buscando en caché local de [McpConnectionRegistry] y consultando clientes remotos.
///
/// POR QUÉ:
/// Cumple SRP extrayendo la lógica de resolución de nombres de [McpToolHandler].
class McpToolResolver {
  const McpToolResolver();

  /// Resuelve una herramienta remota a partir de un identificador textual.
  Future<McpRemoteTool?> resolve(
    McpConnectionRegistry registry,
    String requested,
  ) async {
    McpRemoteTool? lookup() {
      String? exactSlash;
      if (requested.contains('/')) {
        exactSlash = requested;
      } else {
        final serverIds = registry.servers
            .map((server) => server.id)
            .where((id) => requested.startsWith('$id.'))
            .toList(growable: false)
          ..sort((a, b) => b.length.compareTo(a.length));
        if (serverIds.isNotEmpty) {
          final serverId = serverIds.first;
          exactSlash = '$serverId/${requested.substring(serverId.length + 1)}';
        } else if (requested.contains('.')) {
          exactSlash =
              '${requested.substring(0, requested.indexOf('.'))}/'
              '${requested.substring(requested.indexOf('.') + 1)}';
        }
      }
      if (exactSlash != null) {
        final exact = registry.lastTools[exactSlash];
        if (exact != null) return exact;
      }
      final byName = registry.lastTools.values
          .where((tool) => tool.name == requested)
          .toList(growable: false);
      return byName.length == 1 ? byName.single : null;
    }

    var resolved = lookup();
    if (resolved != null) return resolved;

    final directCatalog = <McpRemoteTool>[];
    for (final server in registry.servers) {
      final client = registry.client(server.id);
      if (client == null) continue;
      try {
        directCatalog.addAll(await client.listTools());
      } catch (_) {}
    }

    final directMatches = directCatalog
        .where((tool) =>
            tool.qualifiedName == requested ||
            '${tool.serverId}.${tool.name}' == requested ||
            tool.name == requested)
        .toList(growable: false);
    if (directMatches.length == 1) return directMatches.single;

    await registry.refreshTools();
    return lookup();
  }
}
