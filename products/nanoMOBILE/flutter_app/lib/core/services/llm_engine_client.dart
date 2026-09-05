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
  // Fábrica del client de streaming (uno nuevo por stream para poder cerrarlo
  // en cancelación sin afectar el client compartido). Inyectable en tests.
  final http.Client Function()? _streamClientFactory;
  int _activeStreamRequests = 0;

  /// Señal local para que el watchdog no compita con decode/prefill.
  bool get hasActiveStreamRequest => _activeStreamRequests > 0;

  LLMEngineClient({
    this.baseUrl = 'http://127.0.0.1:8080',
    this.timeout = const Duration(
      seconds: 240,
    ), // Medido en Oppo (1.5B Q4_K_M, ctx 4096): prefill ~125s + decode ~12s
    // ≈ 137s por borrador CON historial de memoria en el prompt. Con 120s el
    // cliente cortaba justo antes de la respuesta; el retry chocaba con el
    // modelo aún ocupado (generation_failed instantáneo) y el borrador ya
    // generado se perdía en el socket muerto. 240s cubre el peor caso con las
    // 8 entradas máximas de historial (~950 tokens de prompt).
    http.Client? client,
    http.Client Function()? streamClientFactory,
  }) : _client = client ?? http.Client(),
       _streamClientFactory = streamClientFactory;

  /// Genera un request_id único para correlacionar la cancelación
  /// (POST /cancel) con la generación en curso. El server lo usa para cortar
  /// el stream y marcar el KV de sesión como dudoso.
  static String newRequestId() =>
      'req-${DateTime.now().microsecondsSinceEpoch}-${++_requestSeq}';

  /// Contador monótono: garantiza unicidad entre request_id generados en el
  /// mismo microsegundo (dos turnos consecutivos inmediatos). Dart es
  /// single-threaded por isolate, así que no hay carrera real.
  static int _requestSeq = 0;

  /// Comprueba si el motor responde. GET /health -> {"status":"ok"}.
  ///
  /// Reintenta con backoff corto: durante el arranque, llama.cpp tarda en
  /// abrir el puerto, así que el primer /health puede fallar por ECONNREFUSED.
  Future<bool> isOnline({
    int attempts = 5,
    Duration requestTimeout = const Duration(seconds: 5),
  }) async {
    final attemptCount = attempts.clamp(1, 20);
    for (var i = 0; i < attemptCount; i++) {
      try {
        final r = await _client
            .get(Uri.parse('$baseUrl/health'))
            .timeout(requestTimeout);
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
        if (i == attemptCount - 1) {
          debugPrint(
            '[llm] health check failed después de $attemptCount intentos: $e',
          );
          return false;
        }
        // Backoff lineal acotado: 500ms, 1s, 1.5s, 2s.
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

  /// Veredicto autoritativo del RuntimePlanner para un artefacto del catálogo.
  /// No replica umbrales de RAM en Dart.
  Future<ViabilityStatus> assessModelViability(int modelSizeBytes) async {
    if (modelSizeBytes <= 0) {
      throw LLMEngineException('modelSizeBytes debe ser mayor que cero');
    }
    final r = await _client
        .post(
          Uri.parse('$baseUrl/api/viability'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'model_size_bytes': modelSizeBytes}),
        )
        .timeout(const Duration(seconds: 5));
    if (r.statusCode != 200) {
      throw LLMEngineException('HTTP ${r.statusCode}: ${r.body}');
    }
    final map = jsonDecode(r.body) as Map<String, dynamic>;
    return ViabilityStatus.fromJson(map);
  }

  /// Genera una respuesta contra /completion (modo no-stream).
  ///
  /// Devuelve el texto y, si el motor lo reporta, el tps real.
  /// Lanza [LLMEngineException] si falla o agota el tiempo.
  Future<LLMResult> generate({
    required String prompt,
    double temperature = 0.7,
    int maxTokens = 256,
    String? sessionId,
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
      // Sesión estable por conversación: el motor reutiliza el KV del turno
      // anterior (gate R5) y el prefill solo procesa los tokens nuevos en
      // vez del prompt completo cada vez. Sin sesión, cada turno paga el
      // prefill entero (~125s en Oppo).
      if (sessionId != null && sessionId.isNotEmpty) 'session_id': sessionId,
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
        debugPrint(
          '[llm] generate timeout attempt ${attempt + 1}/$maxAttempts',
        );
        if (attempt == maxAttempts - 1) {
          throw LLMEngineException(
            'Timeout al generar la respuesta tras $maxAttempts intentos',
          );
        }
        // Backoff progresivo: 1s, 2s
        await Future<void>.delayed(
          Duration(milliseconds: 1000 * (attempt + 1)),
        );
      } on http.ClientException catch (e) {
        debugPrint(
          '[llm] generate connection error attempt ${attempt + 1}/$maxAttempts: ${e.message}',
        );
        if (attempt == maxAttempts - 1) {
          throw LLMEngineException(
            'No se pudo contactar al motor tras $maxAttempts intentos: $e.message',
          );
        }
        await Future<void>.delayed(
          Duration(milliseconds: 1000 * (attempt + 1)),
        );
      } on FormatException catch (e) {
        debugPrint('[llm] generate JSON decode error: $e');
        throw LLMEngineException('Respuesta inválida del motor: ${e.message}');
      }
      // LLMEngineException (HTTP error) se propaga sin retry.
    }
    throw LLMEngineException(
      'No se pudo generar la respuesta tras $maxAttempts intentos',
    );
  }

  /// Genera respuesta streaming contra /completion (modo SSE token-por-token).
  ///
  /// Cada token se emite como [LLMStreamToken]. El último token tiene
  /// `stop: true` y contiene el `tps` reportado por el motor.
  ///
  /// El stream se cancela cerrando el [http.Client] subyacente. Para abortar
  /// una generación en curso, llama a [cancelRequest] o cierra el cliente
  /// retornado por [generateStream].
  ///
  /// Devuelve un record con el [Stream], el [http.Client] usado para que
  /// el llamador pueda cerrarlo (cancelación) y el [String] `requestId`
  /// correlacionado con este turno (autogenerado si no se pasa).
  ({Stream<LLMStreamToken> stream, http.Client client, String requestId})
  generateStream({
    required String prompt,
    double temperature = 0.7,
    double topP = 0.9,
    int maxTokens = 256,
    String? sessionId,
    String? context,
    List<Map<String, String>>? history,
    String? requestId,
  }) {
    final client = _streamClientFactory?.call() ?? http.Client();
    final controller = StreamController<LLMStreamToken>();
    final effectiveRequestId = (requestId != null && requestId.isNotEmpty)
        ? requestId
        : newRequestId();

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
      requestId: effectiveRequestId,
    );

    return (
      stream: controller.stream,
      client: client,
      requestId: effectiveRequestId,
    );
  }

  /// Gate R6 — cancela una generación en curso de forma cooperativa.
  ///
  /// POST /cancel con el request_id: el servidor corta el stream (incluso
  /// durante prefill), y además invalida el KV de la sesión para que el
  /// siguiente turno arranque limpio. Cerrar solo el socket (lo que hacía el
  /// cliente antes) dejaba la generación corriendo en el worker con KV a
  /// medias. Devuelve true si el server confirmó la cancelación.
  Future<bool> cancelRequest(String requestId) async {
    try {
      final r = await _client
          .post(
            Uri.parse('$baseUrl/cancel'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'request_id': requestId}),
          )
          .timeout(const Duration(seconds: 5));
      final ok = r.statusCode == 200;
      debugPrint('[llm] cancel $requestId -> HTTP ${r.statusCode}');
      return ok;
    } catch (e) {
      debugPrint(
        '[llm] cancel falló (el cierre de socket sigue como fallback): $e',
      );
      return false;
    }
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
    String? requestId,
  }) async {
    _activeStreamRequests++;
    try {
      debugPrint(
        '[llm] startStreamRequest sessionId=${sessionId ?? ''} '
        'prompt_len=${prompt.length} context_len=${context?.length ?? 0} '
        'history_turns=${history?.length ?? 0}',
      );
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
        if (requestId != null && requestId.isNotEmpty) 'request_id': requestId,
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
          Map<String, dynamic>? timings;
          String? phase;
          if (stop) {
            final t = map['timings'];
            if (t is Map<String, dynamic>) {
              timings = t;
              final perSecond = t['predicted_per_second'];
              if (perSecond is num && perSecond > 0) {
                tps = perSecond.toDouble();
              } else {
                final perTokenMs = t['predicted_per_token_ms'];
                if (perTokenMs is num && perTokenMs > 0) {
                  tps = 1000.0 / perTokenMs.toDouble();
                }
              }
            }
          }
          // Heartbeat (Gate R3): frame sin content que informa la fase del
          // motor (model_loading mientras el GGUF carga, generating en prefill
          // largo). El cliente lo usa para mostrar "cargando/esperando".
          if (map['heartbeat'] == true) {
            phase = map['phase'] as String?;
          }

          if (!controller.isClosed) {
            controller.add(
              LLMStreamToken(
                content: content,
                stop: stop,
                tps: tps,
                timings: timings,
                phase: phase,
              ),
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
      if (_activeStreamRequests > 0) _activeStreamRequests--;
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

  /// Gate R10 — timings del frame final (ttft_ms, prefill_ms, decode_tok_s...).
  final Map<String, dynamic>? timings;

  /// Gate R3 — fase del heartbeat (`model_loading` | `generating`), si aplica.
  final String? phase;
  const LLMStreamToken({
    required this.content,
    required this.stop,
    this.tps,
    this.timings,
    this.phase,
  });
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

  /// `null` significa sensor no expuesto; nunca se sustituye por un valor
  /// térmico inventado.
  final double? temperatureC;
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
    required this.temperatureC,
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
    temperatureC: (j['temperature_c'] as num?)?.toDouble(),
    viability: j['viability'] is Map<String, dynamic>
        ? ViabilityStatus.fromJson(j['viability'] as Map<String, dynamic>)
        : null,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RuntimeStatus &&
          modelLoaded == other.modelLoaded &&
          modelSizeMb == other.modelSizeMb &&
          contextSize == other.contextSize &&
          faultRate == other.faultRate &&
          pssMb == other.pssMb &&
          pressureRatio == other.pressureRatio &&
          thrashing == other.thrashing &&
          residentWindow == other.residentWindow &&
          tokS == other.tokS &&
          temperatureC == other.temperatureC &&
          viability == other.viability;

  @override
  int get hashCode => Object.hash(
    modelLoaded,
    modelSizeMb,
    contextSize,
    faultRate,
    pssMb,
    pressureRatio,
    thrashing,
    residentWindow,
    tokS,
    temperatureC,
    viability,
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

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ViabilityStatus &&
          tier == other.tier &&
          canRun == other.canRun &&
          shouldRunInteractive == other.shouldRunInteractive &&
          reason == other.reason;

  @override
  int get hashCode => Object.hash(tier, canRun, shouldRunInteractive, reason);
}
