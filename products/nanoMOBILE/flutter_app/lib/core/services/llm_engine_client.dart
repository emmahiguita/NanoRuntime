import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

/// Cliente HTTP hacia el motor llama.cpp real desplegado localmente en el
/// dispositivo (binario `nan`, libs en `llama_libs/`, modelos `.gguf`).
///
/// El motor se lanza en el propio dispositivo:
///   nanortime --server --port 8080 --model qwen.gguf
///
/// La app se conecta a 127.0.0.1 (loopback). SSE streaming vía POST /completion
/// (compatible con la API del servidor HTTP+SSE integrado en nanortime-cli).
class LLMEngineClient {
  final String baseUrl;
  final Duration timeout;
  final http.Client _client;

  LLMEngineClient({
    this.baseUrl = 'http://127.0.0.1:8080',
    this.timeout = const Duration(seconds: 60),
  }) : _client = http.Client();

  /// Comprueba si el motor responde. GET /health -> {"status":"ok"}.
  ///
  /// Reintenta con backoff corto: durante el arranque, llama.cpp tarda en
  /// abrir el puerto, así que el primer /health puede fallar por ECONNREFUSED.
  Future<bool> isOnline() async {
    const attempts = 3;
    for (var i = 0; i < attempts; i++) {
      try {
        final r = await _client
            .get(Uri.parse('$baseUrl/health'))
            .timeout(const Duration(seconds: 3));
        return r.statusCode == 200;
      } catch (_) {
        if (i == attempts - 1) return false;
        // Backoff exponencial: 300ms, 600ms.
        await Future<void>.delayed(Duration(milliseconds: 300 * (i + 1)));
      }
    }
    return false;
  }

  /// GET /api/status → true si el runtime tiene un modelo cargado.
  ///
  /// 503 runtime_unavailable = server model-free (--no-model): el motor
  /// está vivo pero sin GGUF instalado — la UI muestra el estado degraded.
  Future<bool> hasModel() async {
    try {
      final r = await _client
          .get(Uri.parse('$baseUrl/api/status'))
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
      'repeat_penalty': 1.1,
      'stop': [
        '<|im_end|>',
        '<|endoftext|>',
        '<|im_start|>',
        '<｜end of sentence｜>',
        '<｜end▁of▁sentence｜>',
      ],
      'stream': false,
    });
    // Un solo reintento ante fallos transitorios (timeout/conexión).
    // Errores HTTP o formato inválido NO se reintentan: son deterministas.
    const maxAttempts = 2;
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
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
        if (attempt == maxAttempts - 1) {
          throw LLMEngineException('Timeout al generar la respuesta');
        }
        // Short backoff antes del reintento (500ms).
        await Future<void>.delayed(Duration(milliseconds: 500 * (attempt + 1)));
      } on http.ClientException catch (e) {
        if (attempt == maxAttempts - 1) {
          throw LLMEngineException(
            'No se pudo contactar al motor: ${e.message}',
          );
        }
        await Future<void>.delayed(Duration(milliseconds: 500 * (attempt + 1)));
      }
      // FormatException y LLMEngineException (HTTP error) se propagan sin retry.
    }
    throw LLMEngineException('No se pudo generar la respuesta');
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
    String? sessionId,
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
      sessionId: sessionId,
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
    String? sessionId,
  }) async {
    try {
      debugPrint('[llm] startStreamRequest sessionId=${sessionId ?? ''} prompt_len=${prompt.length}');
      final request = http.Request('POST', Uri.parse('$baseUrl/completion'));
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode({
        'prompt': prompt,
        'n_predict': maxTokens,
        'temperature': temperature,
        'top_p': topP,
        'repeat_penalty': 1.1,
        'stop': [
          '<|im_end|>',
          '<|endoftext|>',
          '<|im_start|>',
          '<｜end of sentence｜>',
          '<｜end▁of▁sentence｜>',
        ],
        'stream': true,
        if (sessionId != null && sessionId.isNotEmpty) 'session_id': sessionId,
      });

      final streamedResponse = await client.send(request).timeout(timeout);

      if (streamedResponse.statusCode != 200) {
        final body = await streamedResponse.stream.bytesToString();
        controller.addError(
          LLMEngineException('HTTP ${streamedResponse.statusCode}: $body'),
        );
        await controller.close();
        client.close();
        return;
      }

      // SSE: cada línea es "data: {json}" seguida de línea vacía.
      final lines = streamedResponse.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter());

      await for (final line in lines) {
        debugPrint('[llm] sse line: $line');
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
          controller.add(
            LLMStreamToken(content: content, stop: stop, tps: tps),
          );
          if (stop) break;
        } on FormatException {
          debugPrint('[llm] sse line malformed: $line');
          // línea SSE malformada: ignorar, continuar con la siguiente.
        }
      }
    } on TimeoutException {
      controller.addError(
        LLMEngineException('Timeout al generar la respuesta'),
      );
    } on http.ClientException catch (e) {
      // Si el client se cerró externamente (cancelación), no reportamos error.
      if (!controller.isClosed) {
        controller.addError(
          LLMEngineException('No se pudo contactar al motor: ${e.message}'),
        );
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
