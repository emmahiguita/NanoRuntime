import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import 'meta_template_models.dart';

/// Configuración pública del gateway y estado de credenciales, nunca el secreto.
class MetaTemplatesConnection {
  const MetaTemplatesConnection({
    required this.endpoint,
    required this.ready,
    required this.agentUsesCloud,
  });
  final String endpoint;
  final bool ready;
  final bool agentUsesCloud;
}

/// Adaptador HTTP: móvil habla con Nano; el token de Meta permanece en servidor.
class MetaTemplatesApi {
  MetaTemplatesApi({FlutterSecureStorage? storage, http.Client? client})
    : _storage = storage ?? const FlutterSecureStorage(),
      _client = client ?? http.Client();

  static const _endpointKey = 'nano.business.meta.endpoint.v1';
  static const _apiKey = 'nano.business.meta.gateway_key.v1';
  static const _providerKey = 'nano.business.whatsapp.provider.v1';
  static const _requestTimeout = Duration(seconds: 25);
  final FlutterSecureStorage _storage;
  final http.Client _client;

  /// Lee los ajustes para mostrar la conexión sin exponer el token guardado.
  Future<MetaTemplatesConnection> connection() async {
    final endpoint = await _storage.read(key: _endpointKey) ?? '';
    final key = await _storage.read(key: _apiKey) ?? '';
    final provider = await _storage.read(key: _providerKey) ?? 'installed_app';
    return MetaTemplatesConnection(
      endpoint: endpoint,
      ready: endpoint.isNotEmpty && key.isNotEmpty,
      agentUsesCloud: provider == 'meta_cloud',
    );
  }

  /// Guarda HTTPS y la llave propia del gateway cifrada por el sistema.
  Future<void> configure(
    String endpoint,
    String apiKey, {
    required bool agentUsesCloud,
  }) async {
    final uri = Uri.tryParse(endpoint.trim());
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        (uri.path.isNotEmpty && uri.path != '/')) {
      throw const FormatException(
        'El servidor debe usar una dirección HTTPS válida.',
      );
    }
    if (apiKey.trim().length < 32) {
      throw const FormatException(
        'La llave de Nano debe tener al menos 32 caracteres.',
      );
    }
    await _storage.write(
      key: _endpointKey,
      value: uri
          .replace(path: '', query: null)
          .toString()
          .replaceFirst(RegExp(r'/$'), ''),
    );
    await _storage.write(key: _apiKey, value: apiKey.trim());
    // Mantiene la ruta de envío explícita; la app local sigue siendo el default.
    await _storage.write(
      key: _providerKey,
      value: agentUsesCloud ? 'meta_cloud' : 'installed_app',
    );
  }

  /// Elimina solo los datos de conexión móvil; no toca credenciales del servidor.
  Future<void> disconnect() async {
    await _storage.delete(key: _endpointKey);
    await _storage.delete(key: _apiKey);
    await _storage.delete(key: _providerKey);
  }

  /// Lee datos actuales de Meta; un fallo remoto se propaga como error visible.
  Future<List<MetaMessageTemplate>> listTemplates() async {
    final data = await _request('GET', '/api/v1/whatsapp/templates');
    return [
      for (final item in (data['data'] as List? ?? const []))
        if (item is Map)
          MetaMessageTemplate.fromJson(item.cast<String, dynamic>()),
    ];
  }

  /// Envía el borrador para revisión oficial; no marca aprobación localmente.
  Future<void> create(MetaMessageTemplateDraft draft) async =>
      _request('POST', '/api/v1/whatsapp/templates', body: draft.toJson());

  /// Cambia los componentes del recurso remoto identificado por Meta.
  Future<void> update(
    MetaMessageTemplate template,
    MetaMessageTemplateDraft draft,
  ) async => _request(
    'PUT',
    '/api/v1/whatsapp/templates/${template.id}',
    body: {'category': draft.category, 'components': draft.components},
  );

  /// La API oficial requiere el ID y también el nombre al borrar.
  Future<void> delete(MetaMessageTemplate template) async => _request(
    'DELETE',
    '/api/v1/whatsapp/templates/${template.id}',
    query: {'name': template.name},
  );

  /// Usa el endpoint oficial; la respuesta contiene el ID real aceptado por Meta.
  Future<String> sendText(String recipient, String text) async {
    final data = await _request(
      'POST',
      '/api/v1/whatsapp/messages',
      body: {'to': recipient, 'text': text},
    );
    final messages = data['messages'] as List? ?? const [];
    final first = messages.isNotEmpty ? messages.first : null;
    final id = first is Map ? first['id']?.toString() : null;
    if (id == null || id.isEmpty) {
      throw const FormatException(
        'Meta no devolvió un ID de mensaje aceptado.',
      );
    }
    return id;
  }

  /// Centraliza autenticación, límite de espera y errores del servidor.
  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? query,
  }) async {
    final connection = await this.connection();
    final key = await _storage.read(key: _apiKey) ?? '';
    if (!connection.ready) {
      throw const FormatException(
        'Configura primero el servidor oficial de Nano.',
      );
    }
    final base = Uri.parse(connection.endpoint);
    final uri = base.replace(path: '${base.path}$path', queryParameters: query);
    final headers = {'X-Nano-API-Key': key, 'Accept': 'application/json'};
    try {
      final request = http.Request(method, uri)..headers.addAll(headers);
      if (body != null) {
        request.headers['Content-Type'] = 'application/json';
        request.body = jsonEncode(body);
      }
      final streamed = await _client.send(request).timeout(_requestTimeout);
      final response = await http.Response.fromStream(
        streamed,
      ).timeout(_requestTimeout);
      final decoded = response.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(response.body);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final remoteError = decoded is Map ? decoded['error'] : null;
        final detail = decoded is Map
            ? decoded['detail'] ??
                  (remoteError is Map ? remoteError['message'] : null)
            : null;
        throw Exception(
          detail?.toString() ??
              'El servidor respondió HTTP ${response.statusCode}.',
        );
      }
      return decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    } on http.ClientException {
      throw Exception('No fue posible conectar con el servidor de Nano.');
    } on TimeoutException {
      throw Exception('El servidor de Nano no respondió a tiempo.');
    } on FormatException {
      rethrow;
    }
  }

  /// Cierra el cliente al salir para no dejar sockets vivos.
  void dispose() => _client.close();
}
