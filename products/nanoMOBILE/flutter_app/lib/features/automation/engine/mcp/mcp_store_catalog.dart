/// Catálogo local de opciones MCP que sí se pueden configurar desde Nano.
///
/// La búsqueda solo filtra estas opciones instaladas; no consulta tiendas remotas.
/// Los servidores externos requieren una URL real y sus herramientas se descubren
/// durante la conexión, nunca se inventan desde ejemplos del catálogo.
library;

import 'mcp_client_port.dart';

enum McpStoreCategory { all, system, developer, search, cloudAi, productivity }

class McpStoreItem {
  const McpStoreItem({
    required this.id,
    required this.name,
    required this.author,
    required this.category,
    required this.description,
    required this.repositoryUrl,
    required this.defaultEndpoint,
    this.transport = McpTransportKind.sse,
    this.isVerified = false,
    this.tags = const [],
    this.sampleTools = const [],
  });

  final String id;
  final String name;
  final String author;
  final McpStoreCategory category;
  final String description;
  final String repositoryUrl;
  final String defaultEndpoint;
  final McpTransportKind transport;
  final bool isVerified;
  final List<String> tags;
  final List<String> sampleTools;

  McpServerDescriptor toDescriptor({
    String? customServerId,
    String? customDisplayName,
    String? customEndpoint,
    String? credentialRef,
  }) {
    return McpServerDescriptor(
      id: customServerId ?? id,
      displayName: customDisplayName ?? name,
      transport: transport,
      endpoint: customEndpoint ?? defaultEndpoint,
      credentialRef: credentialRef,
      metadata: {'author': author, 'repository': repositoryUrl, 'tags': tags},
    );
  }
}

class McpStoreCatalog {
  const McpStoreCatalog();

  // QUÉ HACE: ofrece solo el conector Android implementado y una plantilla remota.
  // CÓMO FUNCIONA: el cliente local enumera sus herramientas reales; la plantilla
  // requiere que la persona ingrese un endpoint MCP Streamable HTTP válido.
  // POR QUÉ: los endpoints localhost y Gemini /v1beta/mcp anteriores no eran
  // servidores MCP garantizados y podían responder 404 aunque la UI dijera "verificado".
  static const List<McpStoreItem> defaultItems = [
    McpStoreItem(
      // Debe coincidir con el descriptor del cliente local ya registrado.
      id: 'device',
      name: 'Local Device Inspector',
      author: 'NanoAI',
      category: McpStoreCategory.system,
      description:
          'Herramientas MCP locales implementadas por Nano para Android.',
      repositoryUrl: '',
      defaultEndpoint: 'local://android.device',
      transport: McpTransportKind.androidBinder,
      isVerified: true,
      tags: ['android', 'local'],
    ),
    McpStoreItem(
      id: 'mcp.remote.streamable_http',
      name: 'Servidor MCP remoto propio',
      author: 'Endpoint configurable',
      category: McpStoreCategory.developer,
      description:
          'Conecta un servidor real compatible con Streamable HTTP. Nano no aloja ese servidor ni lo usa como modelo conversacional.',
      repositoryUrl: '',
      defaultEndpoint: '',
      transport: McpTransportKind.streamableHttp,
      tags: ['mcp', 'streamable-http', 'remote'],
    ),
  ];

  List<McpStoreItem> search({
    String query = '',
    McpStoreCategory category = McpStoreCategory.all,
  }) {
    final q = query.trim().toLowerCase();
    return defaultItems.where((item) {
      if (category != McpStoreCategory.all && item.category != category) {
        return false;
      }
      if (q.isEmpty) return true;

      final matchName = item.name.toLowerCase().contains(q);
      final matchDesc = item.description.toLowerCase().contains(q);
      final matchAuthor = item.author.toLowerCase().contains(q);
      final matchTag = item.tags.any((t) => t.toLowerCase().contains(q));
      final matchTool = item.sampleTools.any(
        (t) => t.toLowerCase().contains(q),
      );

      return matchName || matchDesc || matchAuthor || matchTag || matchTool;
    }).toList();
  }

  List<McpStoreItem> query({
    String searchQuery = '',
    McpStoreCategory category = McpStoreCategory.all,
  }) => search(query: searchQuery, category: category);
}
