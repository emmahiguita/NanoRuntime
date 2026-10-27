part of 'meta_templates_api.dart';

/// Lee una instantánea cifrada; las conexiones anteriores conservan solo lectura.
Future<Map<String, String>> _loadMetaGatewayCredentials(
  MetaTemplatesApi api,
) async {
  final stored = await api._storage.read(key: api._credentialsKey);
  if (stored != null) {
    try {
      final value = jsonDecode(stored);
      if (value is Map && value.values.every((item) => item is String)) {
        return value.cast<String, String>();
      }
    } catch (_) {
      // No imprime el JSON cifrado/decodificado ni incluye claves en excepciones.
    }
    throw const FormatException('La conexión privada de Nano no se pudo leer.');
  }
  if (api.lineId != 'default') return {};
  return {
    'endpoint':
        await api._storage.read(key: MetaTemplatesApi._endpointKey) ?? '',
    'read': await api._storage.read(key: MetaTemplatesApi._apiKey) ?? '',
    'provider':
        await api._storage.read(key: MetaTemplatesApi._providerKey) ??
        'installed_app',
  };
}

/// Selecciona una llave por operación; no reutiliza lectura para conceder escritura.
Future<({String endpoint, String key})> _metaGatewayCredential(
  MetaTemplatesApi api,
  String method,
  String path,
) async {
  final values = await _loadMetaGatewayCredentials(api);
  final permission = method == 'GET'
      ? 'read'
      : ['/api/v1/whatsapp/messages', '/api/v1/whatsapp/media'].contains(path)
      ? 'send'
      : 'admin';
  final key = values[permission] ?? '';
  if (key.isEmpty || (values['endpoint'] ?? '').isEmpty) {
    throw FormatException(
      permission == 'read'
          ? 'Configura la conexión de lectura de Nano.'
          : permission == 'send'
          ? 'Configura la llave de envío de Nano.'
          : 'Configura la llave para administrar plantillas.',
    );
  }
  return (endpoint: values['endpoint']!, key: key);
}

/// Valida todo antes de guardar y conserva claves únicamente para el mismo servidor.
Future<void> _configureMetaGatewayCredentials(
  MetaTemplatesApi api,
  String endpoint,
  String readKey, {
  required bool agentUsesCloud,
  required String sendKey,
  required String adminKey,
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
  final normalized = uri
      .replace(path: '')
      .toString()
      .replaceFirst(RegExp(r'/$'), '');
  final previous = await _loadMetaGatewayCredentials(api);
  final sameServer = previous['endpoint'] == normalized;
  final keys = {
    'read': readKey.trim(),
    'send': sendKey.trim(),
    'admin': adminKey.trim(),
  };
  for (final permission in keys.keys) {
    if (keys[permission]!.isEmpty && sameServer) {
      keys[permission] = previous[permission] ?? '';
    }
  }
  if (keys['read']!.isEmpty ||
      keys.values.any(
        (key) =>
            key.isNotEmpty &&
            (key.length < 32 ||
                key.length > 256 ||
                RegExp(r'\s').hasMatch(key)),
      )) {
    throw const FormatException(
      'Cada llave Nano debe tener 32–256 caracteres, sin espacios.',
    );
  }
  final populated = keys.values.where((key) => key.isNotEmpty).toList();
  if (populated.toSet().length != populated.length) {
    throw const FormatException(
      'Usa llaves distintas para lectura, envío y plantillas.',
    );
  }
  if (agentUsesCloud && keys['send']!.isEmpty) {
    throw const FormatException(
      'Para activar Meta Cloud debes configurar la llave de envío.',
    );
  }
  final provider = agentUsesCloud ? 'meta_cloud' : 'installed_app';
  // Un único registro evita combinar URL de una empresa con claves de otra.
  await api._storage.write(
    key: api._credentialsKey,
    value: jsonEncode({'endpoint': normalized, 'provider': provider, ...keys}),
  );
  if (api.lineId != 'default') return;
  // Conserva datos v1 para lectura/rollback, nunca les añade permisos de escritura.
  await api._storage.write(
    key: MetaTemplatesApi._endpointKey,
    value: normalized,
  );
  await api._storage.write(key: MetaTemplatesApi._apiKey, value: keys['read']);
  await api._storage.write(key: MetaTemplatesApi._providerKey, value: provider);
}
