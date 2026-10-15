part of 'meta_templates_api.dart';

/// Transporte único: no sigue redirecciones con la llave privada ni duplica credenciales.
Future<Map<String, dynamic>> _requestMetaGateway(
  MetaTemplatesApi api,
  String method,
  String path, {
  Map<String, dynamic>? body,
  Map<String, String>? query,
}) async {
  if (api._disposed) throw StateError('Conexión de Nano cerrada.');
  final credential = await _metaGatewayCredential(api, method, path);
  final base = Uri.parse(credential.endpoint);
  if (base.scheme != 'https' ||
      base.host.isEmpty ||
      base.userInfo.isNotEmpty ||
      base.hasQuery ||
      base.hasFragment) {
    throw const FormatException('La conexión guardada no es HTTPS válida.');
  }
  final uri = base.replace(path: '${base.path}$path', queryParameters: query);
  final headers = {
    'X-Nano-API-Key': credential.key,
    'Accept': 'application/json',
  };
  if (api._disposed) throw StateError('Conexión de Nano cerrada.');
  final abort = Completer<void>();
  api._activeRequests.add(abort);
  var expired = false;
  // http 1.6 instalado admite abortTrigger en IOClient: cancela también lectura del cuerpo.
  final deadline = Timer(MetaTemplatesApi._requestTimeout, () {
    expired = true;
    if (!abort.isCompleted) abort.complete();
  });
  try {
    final request =
        http.AbortableRequest(method, uri, abortTrigger: abort.future)
          ..followRedirects = false
          ..headers.addAll(headers);
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }
    final streamed = await api._client
        .send(request)
        .timeout(MetaTemplatesApi._requestTimeout);
    final response = await http.Response.fromStream(
      streamed,
    ).timeout(MetaTemplatesApi._requestTimeout);
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
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException(
        'El servidor devolvió un objeto JSON inválido.',
      );
    }
    return decoded;
  } on http.RequestAbortedException {
    throw Exception(
      expired
          ? 'El servidor de Nano no respondió a tiempo.'
          : 'Consulta cancelada.',
    );
  } on http.ClientException {
    throw Exception('No fue posible conectar con el servidor de Nano.');
  } on TimeoutException {
    throw Exception('El servidor de Nano no respondió a tiempo.');
  } on FormatException {
    rethrow;
  } finally {
    deadline.cancel();
    if (!abort.isCompleted) abort.complete();
    api._activeRequests.remove(abort);
  }
}
