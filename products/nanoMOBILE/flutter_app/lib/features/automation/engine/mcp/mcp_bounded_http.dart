import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

/// Peticiones MCP acotadas: detienen SSE al recibir el resultado del ID pedido.
/// Cancelar la lectura libera el transporte; no equivale a cancelar la herramienta.
extension McpBoundedRequests on http.Client {
  Future<http.Response> mcpPost(
    Uri endpoint, {
    required Map<String, String> headers,
    required String body,
    Duration timeout = const Duration(seconds: 12),
  }) async {
    final abort = Completer<void>();
    var expired = false;
    void stop() {
      if (!abort.isCompleted) abort.complete();
    }

    final timer = Timer(timeout, () {
      expired = true;
      stop();
    });
    final request =
        http.AbortableRequest('POST', endpoint, abortTrigger: abort.future)
          ..headers.addAll(headers)
          ..body = body;
    final id = (jsonDecode(body) as Map<String, dynamic>)['id'];
    try {
      return await _readMcpResponse(this, request, id).timeout(timeout);
    } catch (error) {
      if (expired || error is TimeoutException) {
        throw TimeoutException('mcp_response_deadline', timeout);
      }
      rethrow;
    } finally {
      timer.cancel();
      stop();
    }
  }
}

/// Consume hasta 2 MiB por respuesta, también en eventos/latidos sin resultado.
/// El decodificador UTF-8 conserva caracteres divididos entre paquetes.
Future<http.Response> _readMcpResponse(
  http.Client client,
  http.BaseRequest request,
  Object? id,
) async {
  final response = await client.send(request);
  final subscription = StreamIterator<List<int>>(response.stream);
  var bytes = 0;
  Stream<List<int>> bounded() async* {
    try {
      while (await subscription.moveNext()) {
        final chunk = subscription.current;
        bytes += chunk.length;
        if (bytes > 2 * 1024 * 1024) {
          throw const FormatException('mcp_response_too_large');
        }
        yield chunk;
      }
    } finally {
      await subscription.cancel();
    }
  }

  http.Response result(String body) => http.Response(
    body,
    response.statusCode,
    headers: {
      ...response.headers,
      'content-type': 'application/json; charset=utf-8',
    },
  );
  try {
    // No necesitamos guardar cuerpos de error ni respuestas a notificaciones.
    if (response.statusCode < 200 || response.statusCode >= 300 || id == null) {
      return result('');
    }
    final stream = bounded().transform(utf8.decoder);
    if (response.headers['content-type']?.contains('text/event-stream') ==
        true) {
      final data = <String>[];
      await for (final line in stream.transform(const LineSplitter())) {
        if (line.isEmpty && data.isNotEmpty) {
          final event = jsonDecode(data.join('\n'));
          data.clear();
          if (_matchesRpc(event, id)) return result(jsonEncode(event));
        } else if (line.startsWith('data:')) {
          data.add(line.substring(5).trimLeft());
        }
      }
      throw const FormatException('mcp_sse_missing_matching_result');
    }
    final body = await stream.join();
    if (!_matchesRpc(jsonDecode(body), id)) {
      throw const FormatException('mcp_invalid_rpc_response');
    }
    return result(body);
  } finally {
    await subscription.cancel();
  }
}

/// Nunca acepta resultados de otra petición ni notificaciones como respuesta.
bool _matchesRpc(Object? value, Object id) =>
    value is Map<String, dynamic> &&
    value['jsonrpc'] == '2.0' &&
    value['id'] == id &&
    (value.containsKey('result') || value.containsKey('error'));
