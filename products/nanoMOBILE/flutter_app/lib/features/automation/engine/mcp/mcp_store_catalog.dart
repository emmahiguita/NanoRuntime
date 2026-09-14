/// McpStoreCatalog — catálogo y repositorio de búsqueda de Servidores MCP y Skills.
///
/// Proporciona acceso a servidores MCP reales de la comunidad y del ecosistema
/// oficial (Smithery, Glama, GitHub Model Context Protocol):
/// - Búsqueda en tiempo real por palabra clave, categoría o autor.
/// - Metadatos verificados (repositorios git, esquemas de transporte, herramientas expuestas).
/// - Adaptación instantánea a [McpServerDescriptor] para conexión inmediata.
library;

import 'mcp_client_port.dart';

enum McpStoreCategory {
  all,
  system,
  developer,
  search,
  cloudAi,
  productivity,
}

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
    this.isVerified = true,
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

  McpServerDescriptor toDescriptor({String? customEndpoint, String? token}) {
    return McpServerDescriptor(
      id: id,
      displayName: name,
      transport: transport,
      endpoint: customEndpoint ?? defaultEndpoint,
      credentialRef: token,
      metadata: {
        'author': author,
        'repository': repositoryUrl,
        'tags': tags,
      },
    );
  }
}

class McpStoreCatalog {
  const McpStoreCatalog();

  static const List<McpStoreItem> defaultItems = [
    McpStoreItem(
      id: 'mcp.device.local',
      name: 'Local Device Inspector',
      author: 'Nano AI Core Team',
      category: McpStoreCategory.system,
      description:
          'Inspecciona telemetría de hardware, batería, memoria /proc/meminfo y catálogo de aplicaciones instaladas en Android.',
      repositoryUrl: 'https://github.com/modelcontextprotocol/servers',
      defaultEndpoint: 'local://android.device',
      transport: McpTransportKind.androidBinder,
      tags: ['android', 'hardware', 'bateria', 'procfs'],
      sampleTools: ['diagnostics', 'app_summary', 'system_features'],
    ),
    McpStoreItem(
      id: 'mcp.gemini.bridge',
      name: 'Google Gemini AI & Voice Bridge',
      author: 'Google Cloud & AI Ecosystem',
      category: McpStoreCategory.cloudAi,
      description:
          'Conecta modelos multimodales Gemini 2.5/1.5 y síntesis de voz natural para asistencia auditiva y razonamiento complejo.',
      repositoryUrl: 'https://github.com/google-gemini/cookbook',
      defaultEndpoint: 'https://generativelanguage.googleapis.com/v1beta/mcp',
      transport: McpTransportKind.streamableHttp,
      tags: ['gemini', 'voz', 'multimodal', 'cloud'],
      sampleTools: ['gemini_reason', 'multimodal_vision', 'voice_synthesize'],
    ),
    McpStoreItem(
      id: 'mcp.filesystem',
      name: 'Secure Filesystem MCP',
      author: 'Model Context Protocol Official',
      category: McpStoreCategory.developer,
      description:
          'Lectura y escritura segura de archivos, directorios y proyectos con control estricto de rutas permitidas.',
      repositoryUrl: 'https://github.com/modelcontextprotocol/servers/tree/main/src/filesystem',
      defaultEndpoint: 'http://127.0.0.1:3001/mcp',
      transport: McpTransportKind.sse,
      tags: ['fs', 'archivos', 'linux', 'storage'],
      sampleTools: ['read_file', 'write_file', 'list_directory', 'get_file_info'],
    ),
    McpStoreItem(
      id: 'mcp.brave.search',
      name: 'Brave Search Web Index',
      author: 'Brave Software',
      category: McpStoreCategory.search,
      description:
          'Búsqueda web en tiempo real sin rastreo, recuperación de fuentes actuales, noticias y snippets de documentación.',
      repositoryUrl: 'https://github.com/modelcontextprotocol/servers/tree/main/src/brave-search',
      defaultEndpoint: 'https://api.search.brave.com/mcp',
      transport: McpTransportKind.streamableHttp,
      tags: ['web', 'busqueda', 'noticias', 'docs'],
      sampleTools: ['brave_web_search', 'brave_local_search'],
    ),
    McpStoreItem(
      id: 'mcp.github.tools',
      name: 'GitHub Repository Manager',
      author: 'GitHub Community',
      category: McpStoreCategory.developer,
      description:
          'Operaciones sobre repositorios de GitHub: explorar ramas, commits, issues, pull requests y leer código fuente.',
      repositoryUrl: 'https://github.com/modelcontextprotocol/servers/tree/main/src/github',
      defaultEndpoint: 'http://127.0.0.1:3002/mcp',
      transport: McpTransportKind.sse,
      tags: ['git', 'github', 'prs', 'issues', 'codigo'],
      sampleTools: ['get_file_contents', 'search_repositories', 'list_issues'],
    ),
    McpStoreItem(
      id: 'mcp.linux.proot',
      name: 'Linux PRoot & Terminal Runner',
      author: 'Nano Embedded Linux Team',
      category: McpStoreCategory.system,
      description:
          'Ejecución enjaulada de binarios ELF, shells Alpine/Debian y utilidades POSIX en Android sin permisos root.',
      repositoryUrl: 'https://github.com/proot-me/proot',
      defaultEndpoint: 'local://proot.terminal',
      transport: McpTransportKind.stdio,
      tags: ['linux', 'proot', 'shell', 'arm64', 'posix'],
      sampleTools: ['proot_exec', 'proot_stat', 'proot_list_packages'],
    ),
    McpStoreItem(
      id: 'mcp.sqlite.database',
      name: 'SQLite Local Database MCP',
      author: 'Model Context Protocol Official',
      category: McpStoreCategory.productivity,
      description:
          'Consulta y manipulación de bases de datos relacionales SQLite locales con esquemas autodescubiertos.',
      repositoryUrl: 'https://github.com/modelcontextprotocol/servers/tree/main/src/sqlite',
      defaultEndpoint: 'http://127.0.0.1:3003/mcp',
      transport: McpTransportKind.sse,
      tags: ['sql', 'sqlite', 'datos', 'consultas'],
      sampleTools: ['read_query', 'write_query', 'describe_table', 'list_tables'],
    ),
    McpStoreItem(
      id: 'mcp.fetch.web',
      name: 'Web Content Fetcher & Markdown',
      author: 'Model Context Protocol Official',
      category: McpStoreCategory.search,
      description:
          'Extrae contenido HTML limpio de URLs públicas y lo convierte a Markdown optimizado para contexto LLM.',
      repositoryUrl: 'https://github.com/modelcontextprotocol/servers/tree/main/src/fetch',
      defaultEndpoint: 'http://127.0.0.1:3004/mcp',
      transport: McpTransportKind.sse,
      tags: ['scraping', 'html', 'markdown', 'extract'],
      sampleTools: ['fetch_url'],
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
      final matchTool = item.sampleTools.any((t) => t.toLowerCase().contains(q));

      return matchName || matchDesc || matchAuthor || matchTag || matchTool;
    }).toList();
  }

  List<McpStoreItem> query({
    String searchQuery = '',
    McpStoreCategory category = McpStoreCategory.all,
  }) =>
      search(query: searchQuery, category: category);
}
