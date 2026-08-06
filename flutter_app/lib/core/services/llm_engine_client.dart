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

  void dispose() => _client.close();
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