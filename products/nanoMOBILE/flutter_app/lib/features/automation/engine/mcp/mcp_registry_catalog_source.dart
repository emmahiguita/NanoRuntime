import 'dart:convert';

import 'package:http/http.dart' as http;

/// Ficha pública del registro MCP; los campos remotos nunca se ejecutan como código.
class McpRegistryEntry {
  const McpRegistryEntry({
    required this.name,
    required this.title,
    required this.description,
    required this.version,
    required this.repositoryUrl,
    required this.remotes,
    required this.packageTypes,
    required this.status,
  });

  final String name;
  final String title;
  final String description;
  final String version;
  final String repositoryUrl;
  final List<McpRegistryRemote> remotes;
  final List<String> packageTypes;
  final String status;

  /// Conecta solo endpoints HTTPS Streamable HTTP sin variables ni headers ocultos.
  McpRegistryRemote? get nanoConnectableRemote {
    for (final remote in remotes) {
      final uri = Uri.tryParse(remote.url);
      final secretQuery =
          uri?.queryParameters.keys.any(
            (key) => RegExp(
              r'token|key|auth|secret|credential',
              caseSensitive: false,
            ).hasMatch(key),
          ) ??
          true;
      if (remote.type == 'streamable-http' &&
          !remote.hasVariables &&
          !remote.hasCustomHeaders &&
          uri?.scheme == 'https' &&
          uri?.host.isNotEmpty == true &&
          uri?.userInfo.isEmpty == true &&
          !secretQuery &&
          !{'deprecated', 'deleted'}.contains(status)) {
        return remote;
      }
    }
    return null;
  }

  /// Convierte una respuesta del registro en datos presentables sin asumir campos opcionales.
  factory McpRegistryEntry.fromResponse(Object? value) {
    final outer = _map(value);
    final server = _map(outer['server']).isNotEmpty
        ? _map(outer['server'])
        : outer;
    final meta = _map(outer['_meta']);
    final official = _map(meta['io.modelcontextprotocol.registry/official']);
    final repository = _map(server['repository']);
    final remotes = _list(server['remotes'])
        .map(McpRegistryRemote.fromResponse)
        .whereType<McpRegistryRemote>()
        .toList(growable: false);
    final packages = _list(server['packages'])
        .map((item) => _map(item)['registryType'])
        .whereType<String>()
        .toSet()
        .toList(growable: false);
    return McpRegistryEntry(
      name: _limited(server['name'], 'unknown', 180),
      title: _limited(
        server['title'],
        _string(server['name'], 'Servidor MCP'),
        120,
      ),
      description: _limited(
        server['description'],
        'Sin descripción publicada.',
        800,
      ),
      version: _limited(server['version'], 'Versión no publicada', 60),
      repositoryUrl: _limited(repository['url'], '', 320),
      remotes: remotes,
      packageTypes: packages,
      status: _string(official['status'], 'unknown'),
    );
  }
}

/// Declara el tipo de transporte y requisitos publicados por el servidor.
class McpRegistryRemote {
  const McpRegistryRemote(
    this.type,
    this.url,
    this.hasVariables,
    this.hasCustomHeaders,
  );

  final String type;
  final String url;
  final bool hasVariables;
  final bool hasCustomHeaders;

  /// Lee un transporte remoto del formato server.json publicado por MCP Registry.
  static McpRegistryRemote? fromResponse(Object? value) {
    final map = _map(value);
    final type = _string(map['type'], '');
    final url = _string(map['url'], '');
    if (type.isEmpty || url.isEmpty) return null;
    return McpRegistryRemote(
      type,
      url,
      _map(map['variables']).isNotEmpty || url.contains('{'),
      _list(map['headers']).isNotEmpty,
    );
  }
}

/// Página del directorio; el cursor opaco lo entrega y conserva el servidor.
class McpRegistryPage {
  const McpRegistryPage(this.entries, this.nextCursor);

  final List<McpRegistryEntry> entries;
  final String? nextCursor;
}

/// Consulta el registro público para mostrar fichas reales, sin descargar paquetes.
class McpRegistryCatalogSource {
  McpRegistryCatalogSource({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;

  /// Busca nombres en la API oficial; limita cada página y evita búsquedas por tecla.
  Future<McpRegistryPage> search({String query = '', String? cursor}) async {
    final uri = Uri.https('registry.modelcontextprotocol.io', '/v0.1/servers', {
      'limit': '12',
      'version': 'latest',
      if (query.trim().isNotEmpty) 'search': query.trim(),
      if (cursor?.isNotEmpty == true) 'cursor': cursor!,
    });
    final response = await _client
        .get(uri)
        .timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) {
      throw McpRegistryException(
        'El registro respondió ${response.statusCode}.',
      );
    }
    final payload = jsonDecode(response.body);
    if (payload is! Map<String, dynamic> || payload['servers'] is! List) {
      throw const McpRegistryException(
        'La respuesta del registro no tiene formato válido.',
      );
    }
    final metadata = _map(payload['metadata']);
    final entries = (payload['servers'] as List)
        .map(McpRegistryEntry.fromResponse)
        .where((entry) => entry.name != 'unknown')
        .toList(growable: false);
    return McpRegistryPage(
      List.unmodifiable(entries),
      metadata['nextCursor'] is String
          ? metadata['nextCursor'] as String
          : null,
    );
  }

  /// Cierra el cliente HTTP cuando se abandona la pantalla del catálogo.
  void dispose() => _client.close();
}

/// Error de red legible para mantener visible el resto del catálogo sin fingir datos.
class McpRegistryException implements Exception {
  const McpRegistryException(this.message);
  final String message;
  @override
  String toString() => message;
}

Map<String, dynamic> _map(Object? value) =>
    value is Map<String, dynamic> ? value : const {};

List<Object?> _list(Object? value) => value is List ? value : const [];

String _string(Object? value, String fallback) =>
    value is String && value.trim().isNotEmpty ? value.trim() : fallback;

String _limited(Object? value, String fallback, int length) {
  final text = _string(value, fallback);
  return text.length > length ? text.substring(0, length) : text;
}
