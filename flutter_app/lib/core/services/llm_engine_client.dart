import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

/// Cliente HTTP hacia el motor llama.cpp real desplegado localmente en el
/// dispositivo (binario `nan`, libs en `llama_libs/`, modelos `.gguf`).
///
/// El motor se lanza en el propio dispositivo:
///   nanortime --server --host 127.0.0.1 --port 8080 --model qwen.gguf
///
/// La app se conecta a 127.0.0.1 (loopback del propio móvil). Usa la API de
/// llama.cpp: GET /health y POST /completion.
class LLMEngineClient {
  final String baseUrl;
  final Duration timeout;
  final http.Client _client;

  LLMEngineClient({
    this.baseUrl = 'http://127.0.0.1:8080',
    this.timeout = const Duration(seconds: 60),
  }) : _client = http.Client();

  /// Comprueba si el motor responde. GET /health -> {"status":"ok"}.
  Future<bool> isOnline() async {
    try {
      final r = await _client
          .get(Uri.parse('$baseUrl/health'))
          .timeout(const Duration(seconds: 3));
      return r.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Genera una respuesta contra /completion (modo no-stream).
  ///
  /// Devuelve el texto y, si el motor lo reporta, el tps real.
  /// Lanza [LLMEngineException] si falla o agota el tiempo.
  Future<LLMResult> generate({
    required String prompt,
    double temperature = 0.7,
    int maxTokens = 256,
  }) async {
    final body = jsonEncode({
      'prompt': prompt,
      'n_predict': maxTokens,
      'temperature': temperature,
      'stream': false,
    });
    try {
      final r = await _client
          .post(
            Uri.parse('$baseUrl/completion'),
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(timeout);

      if (r.statusCode != 200) {
        throw LLMEngineException('HTTP ${r.statusCode}: ${r.body}');
      }

      final map = jsonDecode(r.body) as Map<String, dynamic>;
      final text = (map['content'] as String? ?? '').trim();

      double? tps;
      final timings = map['timings'];
      if (timings is Map<String, dynamic>) {
        // llama.cpp reporta predicted_per_second (tokens/s) y
        // predicted_per_token_ms. Preferimos el valor directo en t/s.
        final perSecond = timings['predicted_per_second'];
        if (perSecond is num && perSecond > 0) {
          tps = perSecond.toDouble();
        } else {
          final perTokenMs = timings['predicted_per_token_ms'];
          if (perTokenMs is num && perTokenMs > 0) {
            tps = 1000.0 / perTokenMs.toDouble();
          }
        }
      }

      return LLMResult(text: text, tps: tps);
    } on TimeoutException {
      throw LLMEngineException('Timeout al generar la respuesta');
    } on http.ClientException catch (e) {
      throw LLMEngineException('No se pudo contactar al motor: ${e.message}');
    } on FormatException {
      throw LLMEngineException('Respuesta del motor no válida');
    }
  }

  /// Genera respuesta streaming contra /completion (modo SSE token-por-token).
  ///
  /// Cada token se emite como [LLMStreamToken]. El último token tiene
  /// `stop: true` y contiene el `tps` reportado por el motor.
  ///
  /// El stream se cancela cerrando el [http.Client] subyacente. Para abortar
  /// una generación en curso, llama a [cancelStream] o cierra el cliente
  /// retornado por [generateStream].
  ///
  /// Devuelve un record con el [Stream] y el [http.Client] usado para que
  /// el llamador pueda cerrarlo (cancelación).
  ({Stream<LLMStreamToken> stream, http.Client client}) generateStream({
    required String prompt,
    double temperature = 0.7,
    double topP = 0.9,
    int maxTokens = 256,
  }) {
    final client = http.Client();
    final controller = StreamController<LLMStreamToken>();

    // Lanzamos la petición en background y puenteamos los tokens al controller.
    // Esto permite cancelar cerrando el client sin esperar al future del stream.
    _startStreamRequest(
      client: client,
      controller: controller,
      prompt: prompt,
      temperature: temperature,
      topP: topP,
      maxTokens: maxTokens,
    );

    return (stream: controller.stream, client: client);
  }

  Future<void> _startStreamRequest({
    required http.Client client,
    required StreamController<LLMStreamToken> controller,
    required String prompt,
    required double temperature,
    required double topP,
    required int maxTokens,
  }) async {
    try {
      final request = http.Request('POST', Uri.parse('$baseUrl/completion'));
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode({
        'prompt': prompt,
        'n_predict': maxTokens,
        'temperature': temperature,
        'top_p': topP,
        'stream': true,
      });

      final streamedResponse = await client.send(request).timeout(timeout);

      if (streamedResponse.statusCode != 200) {
        final body = await streamedResponse.stream.bytesToString();
        controller.addError(LLMEngineException('HTTP ${streamedResponse.statusCode}: $body'));
        await controller.close();
        client.close();
        return;
      }

      // SSE: cada línea es "data: {json}" seguida de línea vacía.
      final lines = streamedResponse.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter());

      await for (final line in lines) {
        if (line.isEmpty || !line.startsWith('data: ')) continue;
        final jsonStr = line.substring(6); // quitar prefijo "data: "
        try {
          final map = jsonDecode(jsonStr) as Map<String, dynamic>;
          final content = map['content'] as String? ?? '';
          final stop = map['stop'] as bool? ?? false;
          double? tps;
          if (stop) {
            final timings = map['timings'];
            if (timings is Map<String, dynamic>) {
              final perSecond = timings['predicted_per_second'];
              if (perSecond is num && perSecond > 0) {
                tps = perSecond.toDouble();
              } else {
                final perTokenMs = timings['predicted_per_token_ms'];
                if (perTokenMs is num && perTokenMs > 0) {
                  tps = 1000.0 / perTokenMs.toDouble();
                }
              }
            }
          }
          controller.add(LLMStreamToken(content: content, stop: stop, tps: tps));
          if (stop) break;
        } on FormatException {
          // línea SSE malformada: ignorar, continuar con la siguiente.
        }
      }
    } on TimeoutException {
      controller.addError(LLMEngineException('Timeout al generar la respuesta'));
    } on http.ClientException catch (e) {
      // Si el client se cerró externamente (cancelación), no reportamos error.
      if (!controller.isClosed) {
        controller.addError(LLMEngineException('No se pudo contactar al motor: ${e.message}'));
      }
    } catch (e) {
      if (!controller.isClosed) {
        controller.addError(LLMEngineException('Error inesperado: $e'));
      }
    } finally {
      await controller.close();
      client.close();
    }
  }

  void dispose() => _client.close();
}

/// Token individual del stream SSE de llama.cpp.
class LLMStreamToken {
  final String content;
  final bool stop;
  final double? tps;
  const LLMStreamToken({required this.content, required this.stop, this.tps});
}

class LLMResult {
  final String text;
  final double? tps;
  const LLMResult({required this.text, this.tps});
}

class LLMEngineException implements Exception {
  final String message;
  LLMEngineException(this.message);
  @override
  String toString() => 'LLMEngineException: $message';
}