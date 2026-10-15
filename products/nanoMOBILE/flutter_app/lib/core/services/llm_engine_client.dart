import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'inference_media_input.dart';
import '../../features/automation/engine/model/inference_telemetry.dart'
    show InferenceTelemetry;

/// Cliente HTTP hacia el motor llama.cpp real desplegado localmente en el
/// dispositivo (binario `nan`, libs en `llama_libs/`, modelos `.gguf`).
///
/// El motor se lanza en el propio dispositivo:
///   nanortime --server --port 8080 --model qwen.gguf
///
/// La app se conecta a 127.0.0.1 (loopback). SSE streaming vía POST /completion
/// (compatible con la API del servidor HTTP+SSE integrado en nanortime-cli).
class LLMEngineClient {
  String baseUrl;
  String? apiKey;
  final Duration timeout;

  void updateEndpoint({required String baseUrl, String? apiKey}) {
    this.baseUrl = baseUrl;
    this.apiKey = apiKey;
  }
  // El router puede ampliar la espera de prefill según el motor sin cambiar el contrato del chat.
  Duration get streamIdleTimeout => const Duration(seconds: 45);
  final http.Client _client;
  // Fábrica del client de streaming (uno nuevo por stream para poder cerrarlo
  // en cancelación sin afectar el client compartido). Inyectable en tests.
  final http.Client Function()? _streamClientFactory;
  int _activeStreamRequests = 0;

  /// Señal local para que el watchdog no compita con decode/prefill.
  bool get hasActiveStreamRequest => _activeStreamRequests > 0;

  Map<String, String> get _authHeaders => {
    if (apiKey != null && apiKey!.isNotEmpty)
      'Authorization': 'Bearer $apiKey',
    if (apiKey != null && apiKey!.isNotEmpty)
      'X-Nano-API-Key': apiKey!,
  };

  LLMEngineClient({
    this.baseUrl = 'http://127.0.0.1:8080',
    this.apiKey,
    this.timeout = const Duration(
      seconds: 240,
    ),
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
            .get(Uri.parse('$baseUrl/health'), headers: _authHeaders)
            .timeout(requestTimeout);
        if (r.statusCode == 200) {
          final body = r.body;
          if (body.contains('"status":"ok"')) {
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
          .get(Uri.parse('$baseUrl/api/status'), headers: _authHeaders)
          .timeout(const Duration(seconds: 3));
      // QUÉ HACE: Distingue fallo HTTP, carga pendiente y modelo realmente listo.
      // CÓMO FUNCIONA: Lee model_loaded y conserva state/error sin registrar prompts.
      // POR QUÉ: El diagnóstico anterior ocultaba el motivo y confundía salud con capacidad de inferencia.
      final decoded = jsonDecode(r.body);
      final status = decoded is Map ? decoded : const <String, dynamic>{};
      final loaded = r.statusCode == 200 && status['model_loaded'] == true;
      if (!loaded) {
        final state = status['state'] ?? status['status'] ?? 'unknown';
        final cause = status['reason'] ?? status['error'] ?? 'model_loaded=false';
        final detail = cause.toString().replaceAll(RegExp(r'[\r\n]+'), ' ');
        debugPrint(
          '[llm] readiness=false http=${r.statusCode} state=$state '
          'cause=${detail.length <= 240 ? detail : detail.substring(0, 240)}',
        );
      }
      return loaded;
    } catch (error) {
      debugPrint('[llm] readiness request failed: ${error.runtimeType}');
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
        .get(Uri.parse('$baseUrl/api/status'), headers: _authHeaders)
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
          headers: {'Content-Type': 'application/json', ..._authHeaders},
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
  /// [requestId] y [queuedAtMs] son OPCIONALES (telemetría LOOP-1): si se
  /// pasan, el turno queda correlacionado con la cola del draft writer.
  Future<LLMResult> generate({
    required String prompt,
    double temperature = 0.7,
    int maxTokens = 256,
    String? sessionId,
    String? context,
    List<Map<String, String>>? history,
    Duration? requestTimeout,
    List<InferenceMediaInput> mediaInputs = const [],
    String? requestId,
    int? queuedAtMs,
  }) async {
    // WA-LIVE-02 — request_id SIEMPRE presente (antes solo en streaming):
    // tras un timeout el cliente corta el socket y llama /cancel con este id.
    // Evidencia device: sin cancel, el worker del motor quedaba en
    // "Model temporarily unavailable (streaming in progress)" PERMANENTE
    // (active_requests=0 pero todo POST posterior fallaba o salía vacío).
    final effectiveRequestId = (requestId != null && requestId.isNotEmpty)
        ? requestId
        : newRequestId();
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
      'request_id': effectiveRequestId,
      if (sessionId != null && sessionId.isNotEmpty) 'session_id': sessionId,
      if (context != null && context.isNotEmpty) 'context': context,
      if (history != null && history.isNotEmpty) 'history': history,
    });
    // LOOP-1-TELEMETRY — arranque del turno: solo números, sin contenido.
    final inferenceWatch = Stopwatch()..start();
    InferenceTelemetry.begin(
      conversationId: sessionId ?? '',
      requestId: effectiveRequestId,
      promptChars: prompt.length,
      historyEntries: history?.length ?? 0,
      queuedAtMs: queuedAtMs ?? DateTime.now().millisecondsSinceEpoch,
    );
    try {
      final response = await _client
          .post(
            Uri.parse('$baseUrl/completion'),
            headers: {'Content-Type': 'application/json', ..._authHeaders},
            body: body,
          )
          .timeout(requestTimeout ?? timeout);
      if (response.statusCode != 200) {
        throw LLMEngineException(
          'HTTP ${response.statusCode}: ${response.body}',
        );
      }
      final map = jsonDecode(response.body) as Map<String, dynamic>;
      if (map['stopped_limit'] == true ||
          map['stop_type'] == 'limit' ||
          map['finish_reason'] == 'length') {
        throw LLMEngineException('La generación alcanzó el límite de tokens');
      }
      final text = (map['content'] as String? ?? '').trim();
      double? tps;
      final timings = map['timings'];
      final timingsMap = timings is Map<String, dynamic> ? timings : null;
      if (timingsMap != null) {
        final perSecond = timingsMap['predicted_per_second'];
        final perTokenMs = timingsMap['predicted_per_token_ms'];
        if (perSecond is num && perSecond > 0) {
          tps = perSecond.toDouble();
        } else if (perTokenMs is num && perTokenMs > 0) {
          tps = 1000.0 / perTokenMs.toDouble();
        }
      }
      inferenceWatch.stop();
      InferenceTelemetry.complete(
        requestId: effectiveRequestId,
        prefillMs: _timingMs(timingsMap, const ['prefill_ms', 'prompt_ms', 'ttft_ms']),
        decodeMs: _timingMs(timingsMap, const ['decode_ms', 'predicted_ms']),
        generatedTokens: _timingInt(
          timingsMap,
          const ['predicted_n', 'tokens_predicted', 'n_predict_out'],
        ),
      );
      return LLMResult(text: text, tps: tps, timings: timingsMap);
    } on TimeoutException {
      InferenceTelemetry.markDiscarded(effectiveRequestId);
      await cancelRequest(effectiveRequestId);
      throw LLMEngineException('Timeout al generar la respuesta');
    } on http.ClientException catch (error) {
      InferenceTelemetry.markDiscarded(effectiveRequestId);
      await cancelRequest(effectiveRequestId);
      throw LLMEngineException(
        'No se pudo contactar al motor: ${error.message}',
      );
    } on FormatException catch (error) {
      InferenceTelemetry.markDiscarded(effectiveRequestId);
      throw LLMEngineException(
        'Respuesta inválida del motor: ${error.message}',
      );
    } on LLMEngineException {
      InferenceTelemetry.markDiscarded(effectiveRequestId);
      rethrow;
    }
  }

  /// Extrae un campo numérico de timings por candidatos; 0 si ausente.
  /// Sin fabricar datos: solo refleja lo que el motor reporta.
  static int _timingMs(Map<String, dynamic>? timings, List<String> keys) {
    if (timings == null) return 0;
    for (final key in keys) {
      final v = timings[key];
      if (v is num) return v.round();
      if (v is String) return int.tryParse(v) ?? 0;
    }
    return 0;
  }

  static int _timingInt(Map<String, dynamic>? timings, List<String> keys) {
    if (timings == null) return 0;
    for (final key in keys) {
      final v = timings[key];
      if (v is num) return v.round();
      if (v is String) return int.tryParse(v) ?? 0;
    }
    return 0;
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
    List<InferenceMediaInput> mediaInputs = const [],
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
    InferenceTelemetry.markCancelRequested(requestId);
    try {
      final r = await _client
          .post(
            Uri.parse('$baseUrl/cancel'),
            headers: {'Content-Type': 'application/json', ..._authHeaders},
            body: jsonEncode({'request_id': requestId}),
          )
          .timeout(const Duration(seconds: 5));
      final ok = r.statusCode == 200;
      debugPrint('[llm] cancel $requestId -> HTTP ${r.statusCode}');
      InferenceTelemetry.markCancelCompleted(requestId);
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
      request.headers.addAll(_authHeaders);
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

  /// LOOP-1-TELEMETRY — timings crudos del motor (solo números, sin texto).
  final Map<String, dynamic>? timings;
  const LLMResult({required this.text, this.tps, this.timings});
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
