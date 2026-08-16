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
    this.timeout = const Duration(seconds: 120), // Aumentado de 60 a 120 segundos para dar más tiempo al motor
  }) : _client = http.Client();

  /// Comprueba si el motor responde. GET /health -> {"status":"ok"}.
  ///
  /// Reintenta con backoff corto: durante el arranque, llama.cpp tarda en
  /// abrir el puerto, así que el primer /health puede fallar por ECONNREFUSED.
  Future<bool> isOnline() async {
    const attempts = 5; // Aumentado de 3 a 5 para dar más tiempo al motor
    for (var i = 0; i < attempts; i++) {
      try {
        final r = await _client
            .get(Uri.parse('$baseUrl/health'))
            .timeout(const Duration(seconds: 5)); // Aumentado de 3 a 5 segundos
        if (r.statusCode == 200) {
          final body = r.body;
          if (body.contains('"status":"ok"')) {
            debugPrint('[llm] health check OK: $body');
            return true;
          } else {
            debugPrint('[llm] health check response inválido: $body');
            return false;
          }
        } else {
          debugPrint('[llm] health check HTTP ${r.statusCode}');
          return false;
        }
      } catch (e) {
        if (i == attempts - 1) {
          debugPrint('[llm] health check failed después de $attempts intentos: $e');
          return false;
        }
        // Backoff exponencial: 500ms, 1s, 2s, 4s.
        await Future<void>.delayed(Duration(milliseconds: 500 * (i + 1)));
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

  /// Estado completo del runtime (telemetría + viabilidad) desde /api/status.
  ///
  /// Snapshot REAL del OS: fault_rate, PSS, presión, thrashing, ventana
  /// residente W, tok/s y el verdicto de viabilidad del modelo cargado.
  /// Lanza [LLMEngineException] si el motor no responde.
  Future<RuntimeStatus> getStatus() async {
    final r = await _client
        .get(Uri.parse('$baseUrl/api/status'))
        .timeout(const Duration(seconds: 5));
    if (r.statusCode != 200) {
      throw LLMEngineException('HTTP ${r.statusCode}: ${r.body}');
    }
    final map = jsonDecode(r.body) as Map<String, dynamic>;
    return RuntimeStatus.fromJson(map);
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
    // Aumentado a 3 intentos para mejor tolerancia a fallos transitorios
    const maxAttempts = 3;
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        debugPrint('[llm] generate attempt ${attempt + 1}/$maxAttempts');
        final r = await _client
            .post(
              Uri.parse('$baseUrl/completion'),
              headers: {'Content-Type': 'application/json'},
              body: body,
            )
            .timeout(timeout);

        if (r.statusCode != 200) {
          debugPrint('[llm] generate HTTP ${r.statusCode}: ${r.body}');
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

        debugPrint('[llm] generate success: ${text.length} chars, tps=$tps');
        return LLMResult(text: text, tps: tps);
      } on TimeoutException {
        debugPrint('[llm] generate timeout attempt ${attempt + 1}/$maxAttempts');
        if (attempt == maxAttempts - 1) {
          throw LLMEngineException('Timeout al generar la respuesta tras $maxAttempts intentos');
        }
        // Backoff progresivo: 1s, 2s
        await Future<void>.delayed(Duration(milliseconds: 1000 * (attempt + 1)));
      } on http.ClientException catch (e) {
        debugPrint('[llm] generate connection error attempt ${attempt + 1}/$maxAttempts: ${e.message}');
        if (attempt == maxAttempts - 1) {
          throw LLMEngineException(
            'No se pudo contactar al motor tras $maxAttempts intentos: $e.message',
          );
        }
        await Future<void>.delayed(Duration(milliseconds: 1000 * (attempt + 1)));
      } on FormatException catch (e) {
        debugPrint('[llm] generate JSON decode error: $e');
        throw LLMEngineException('Respuesta inválida del motor: ${e.message}');
      }
      // LLMEngineException (HTTP error) se propaga sin retry.
    }
    throw LLMEngineException('No se pudo generar la respuesta tras $maxAttempts intentos');
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
    String? context,
    List<Map<String, String>>? history,
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
      context: context,
      history: history,
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
    String? context,
    List<Map<String, String>>? history,
  }) async {
    try {
      debugPrint('[llm] startStreamRequest sessionId=${sessionId ?? ''} prompt_len=${prompt.length}');
      final request = http.Request('POST', Uri.parse('$baseUrl/completion'));
      request.headers['Content-Type'] = 'application/json';
      // El prompt viaja CRUDO (sin template): el motor nanortime aplica el
      // chat template real del GGUF. `context` es el system prompt del
      // cliente y `history` los turnos previos (role/content) — el core los
      // inyecta como turnos reales del template.
      request.body = jsonEncode({
        'prompt': prompt,
        'n_predict': maxTokens,
        'temperature': temperature,
        'top_p': topP,
        'repeat_penalty': 1.1,
        'stream': true,
        if (sessionId != null && sessionId.isNotEmpty) 'session_id': sessionId,
        if (context != null && context.isNotEmpty) 'context': context,
        if (history != null && history.isNotEmpty) 'history': history,
      });

      final streamedResponse = await client.send(request).timeout(timeout);

      if (streamedResponse.statusCode != 200) {
        final body = await streamedResponse.stream.bytesToString();
        debugPrint('[llm] stream HTTP ${streamedResponse.statusCode}: $body');
        if (!controller.isClosed) {
          controller.addError(
            LLMEngineException('HTTP ${streamedResponse.statusCode}: $body'),
          );
        }
        await controller.close();
        client.close();
        return;
      }

      debugPrint('[llm] stream connection established, reading SSE');
      // SSE: cada línea es "data: {json}" seguida de línea vacía.
      final lines = streamedResponse.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter());

      int tokenCount = 0;
      await for (final line in lines) {
        if (controller.isClosed) break;
        
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
          
          if (!controller.isClosed) {
            controller.add(
              LLMStreamToken(content: content, stop: stop, tps: tps),
            );
            tokenCount++;
            if (tokenCount % 10 == 0) {
              debugPrint('[llm] streaming... tokens: $tokenCount');
            }
          }
          
          if (stop) {
            debugPrint('[llm] stream complete: $tokenCount tokens, tps=$tps');
            break;
          }
        } on FormatException catch (e) {
          debugPrint('[llm] sse line malformed: $line (error: $e)');
          // línea SSE malformada: ignorar, continuar con la siguiente.
        }
      }
    } on TimeoutException catch (e) {
      debugPrint('[llm] stream timeout: $e');
      if (!controller.isClosed) {
        controller.addError(
          LLMEngineException('Timeout al generar la respuesta streaming'),
        );
      }
    } on http.ClientException catch (e) {
      debugPrint('[llm] stream connection error: ${e.message}');
      // Si el client se cerró externamente (cancelación), no reportamos error.
      if (!controller.isClosed) {
        controller.addError(
          LLMEngineException('No se pudo contactar al motor: ${e.message}'),
        );
      }
    } catch (e) {
      debugPrint('[llm] stream unexpected error: $e');
      if (!controller.isClosed) {
        controller.addError(LLMEngineException('Error inesperado: $e'));
      }
    } finally {
      if (!controller.isClosed) {
        await controller.close();
      }
      client.close();
      debugPrint('[llm] stream resources cleaned up');
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

/// Estado completo del runtime — espejo Dart de `RuntimeStatus` (Rust).
/// Telemetría REAL del OS: nada fabricado.
class RuntimeStatus {
  final bool modelLoaded;
  final int modelSizeMb;
  final int contextSize;
  final double faultRate;
  final double? pssMb;
  final double pressureRatio;
  final bool thrashing;
  final int residentWindow;
  final double tokS;
  final ViabilityStatus? viability;

  const RuntimeStatus({
    required this.modelLoaded,
    required this.modelSizeMb,
    required this.contextSize,
    required this.faultRate,
    required this.pssMb,
    required this.pressureRatio,
    required this.thrashing,
    required this.residentWindow,
    required this.tokS,
    required this.viability,
  });

  factory RuntimeStatus.fromJson(Map<String, dynamic> j) => RuntimeStatus(
        modelLoaded: j['model_loaded'] as bool? ?? false,
        modelSizeMb: (j['model_size_mb'] as num?)?.toInt() ?? 0,
        contextSize: (j['context_size'] as num?)?.toInt() ?? 0,
        faultRate: (j['fault_rate'] as num?)?.toDouble() ?? 0,
        pssMb: (j['pss_mb'] as num?)?.toDouble(),
        pressureRatio: (j['pressure_ratio'] as num?)?.toDouble() ?? 0,
        thrashing: j['thrashing'] as bool? ?? false,
        residentWindow: (j['resident_window'] as num?)?.toInt() ?? 0,
        tokS: (j['tok_s'] as num?)?.toDouble() ?? 0,
        viability: j['viability'] is Map<String, dynamic>
            ? ViabilityStatus.fromJson(j['viability'] as Map<String, dynamic>)
            : null,
      );
}

/// Verdicto de viabilidad (CanRun vs ShouldRun) — espejo de `ViabilityStatus`.
class ViabilityStatus {
  final String tier;
  final bool canRun;
  final bool shouldRunInteractive;
  final String reason;

  const ViabilityStatus({
    required this.tier,
    required this.canRun,
    required this.shouldRunInteractive,
    required this.reason,
  });

  factory ViabilityStatus.fromJson(Map<String, dynamic> j) => ViabilityStatus(
        tier: j['tier'] as String? ?? 'UNKNOWN',
        canRun: j['can_run'] as bool? ?? false,
        shouldRunInteractive: j['should_run_interactive'] as bool? ?? false,
        reason: j['reason'] as String? ?? '',
      );
}
