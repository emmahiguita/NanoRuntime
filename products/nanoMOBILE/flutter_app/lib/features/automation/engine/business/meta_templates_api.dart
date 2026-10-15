import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import 'meta_template_models.dart';
import 'meta_inbox_models.dart';

part 'meta_gateway_transport.dart';
part 'meta_inbox_api.dart';
part 'meta_gateway_credentials.dart';

/// Configuración pública del gateway y estado de credenciales, nunca el secreto.
class MetaTemplatesConnection {
  const MetaTemplatesConnection({
    required this.endpoint,
    required this.ready,
    required this.agentUsesCloud,
    this.sendReady = false,
    this.adminReady = false,
  });
  final String endpoint;
  final bool ready;
  final bool agentUsesCloud;
  final bool sendReady;
  final bool adminReady;
}

/// Adaptador HTTP: móvil habla con Nano; el token de Meta permanece en servidor.
class MetaTemplatesApi {
  MetaTemplatesApi({FlutterSecureStorage? storage, http.Client? client})
    : _storage = storage ?? const FlutterSecureStorage(),
      _client = client ?? http.Client();

  static const _endpointKey = 'nano.business.meta.endpoint.v1';
  static const _apiKey = 'nano.business.meta.gateway_key.v1';
  static const _providerKey = 'nano.business.whatsapp.provider.v1';
  static const _credentialsKey = 'nano.business.meta.credentials.v2';
  static const _requestTimeout = Duration(seconds: 25);
  final FlutterSecureStorage _storage;
  final http.Client _client;
  final _activeRequests = <Completer<void>>{};
  bool _disposed = false;

  /// Lee los ajustes para mostrar la conexión sin exponer el token guardado.
  Future<MetaTemplatesConnection> connection() async {
    final values = await _loadMetaGatewayCredentials(this);
    return MetaTemplatesConnection(
      endpoint: values['endpoint'] ?? '',
      ready:
          (values['endpoint'] ?? '').isNotEmpty &&
          (values['read'] ?? '').isNotEmpty,
      agentUsesCloud: values['provider'] == 'meta_cloud',
      sendReady: (values['send'] ?? '').isNotEmpty,
      adminReady: (values['admin'] ?? '').isNotEmpty,
    );
  }

  /// Guarda HTTPS y la llave propia del gateway cifrada por el sistema.
  Future<void> configure(
    String endpoint,
    String apiKey, {
    required bool agentUsesCloud,
    String sendKey = '',
    String adminKey = '',
  }) => _configureMetaGatewayCredentials(
    this,
    endpoint,
    apiKey,
    agentUsesCloud: agentUsesCloud,
    sendKey: sendKey,
    adminKey: adminKey,
  );

  /// Elimina solo los datos de conexión móvil; no toca credenciales del servidor.
  Future<void> disconnect() async {
    await _storage.delete(key: _credentialsKey);
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

  /// Fachada compartida: plantillas, texto e historial usan la misma conexión segura.
  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? query,
  }) => _requestMetaGateway(this, method, path, body: body, query: query);

  /// Cierra el cliente al salir para no dejar sockets vivos.
  void dispose() {
    _disposed = true;
    // Aborta requests reales antes de cerrar: el timeout no deja sockets huérfanos.
    for (final abort in _activeRequests) {
      if (!abort.isCompleted) abort.complete();
    }
    _activeRequests.clear();
    _client.close();
  }
}
