import 'dart:async';
import 'package:flutter/foundation.dart';

import '../../../core/models/chat_models.dart';
import '../../../core/services/llm_engine_client.dart';
import '../domain/stream_lease.dart';
import '../domain/stream_sanitizer.dart';

/// Coordinador de sesión de streaming para el motor de inferencia local.
///
/// **QUÉ HACE:**
/// Gestiona la conexión HTTP con llama.cpp, control de concurrencia y cancelación.
///
/// **CÓMO FUNCIONA:**
/// Emite tokens con throttle periódico (~32ms) para no saturar el hilo UI de Flutter.
///
/// **POR QUÉ:**
/// Evita colisiones de red, memory leaks por streams huérfanos y libera GPU/NPU al cancelar.
class ChatStreamSession {
  static const Duration streamIdleTimeout = Duration(seconds: 45);

  StreamLease? _activeStream;
  int _generationSequence = 0;
  int? _activeGenerationId;
  int _activeConnections = 0;
  bool _generationCancelled = false;

  Timer? _flushTimer;
  int _lastFlushedLength = 0;

  StreamLease? get activeStream => _activeStream;
  int get activeConnections => _activeConnections;
  bool get isCancelled => _generationCancelled;
  int? get activeGenerationId => _activeGenerationId;

  /// Inicia un nuevo ciclo de generación incrementando la secuencia monótona.
  int beginGeneration() {
    final generationId = ++_generationSequence;
    _activeGenerationId = generationId;
    _generationCancelled = false;
    _lastFlushedLength = 0;
    return generationId;
  }

  /// Comprueba si la generación recibida sigue siendo la vigente y no ha sido cancelada.
  bool isGenerationCurrent(int generationId, bool isMounted) =>
      isMounted && !_generationCancelled && _activeGenerationId == generationId;

  /// Programa el flush del texto con throttle (~32ms), previniendo rebuilds innecesarios.
  void scheduleStreamFlush(
    StringBuffer buffer, {
    required bool Function() isMounted,
    required void Function(String text) onFlush,
  }) {
    if (_flushTimer != null) return;
    _flushTimer = Timer(const Duration(milliseconds: 32), () {
      _flushTimer = null;
      if (isMounted() && !_generationCancelled) {
        final currentLen = buffer.length;
        if (currentLen != _lastFlushedLength) {
          _lastFlushedLength = currentLen;
          try {
            onFlush(buffer.toString());
          } catch (e) {
            debugPrint('[ChatStreamSession] Error en flush: $e');
          }
        }
      }
    });
  }

  /// Cancela el timer de flush pendiente.
  void cancelStreamFlush() {
    _flushTimer?.cancel();
    _flushTimer = null;
    _lastFlushedLength = 0;
  }

  /// Ejecuta la lectura streaming consumiendo `generateStream` del cliente LLM.
  Future<StreamTurnResult> executeStream({
    required LLMEngineClient engine,
    required String prompt,
    required double temperature,
    required double topP,
    required int maxTokens,
    required String sessionId,
    required String systemPrompt,
    required List<Map<String, String>> history,
    required int generationId,
    required bool Function() isMounted,
    required void Function(ModelConnectionState) onPhaseChange,
    required void Function(String streamingText) onTextUpdated,
  }) async {
    final (:stream, :client, :requestId) = engine.generateStream(
      prompt: prompt,
      temperature: temperature,
      topP: topP,
      maxTokens: maxTokens,
      sessionId: sessionId,
      context: systemPrompt,
      history: history,
    );

    final lease = StreamLease(generationId: generationId, client: client, requestId: requestId);
    _activeStream = lease;
    _activeConnections++;
    debugPrint('[ChatStreamSession] Conexión abierta: $_activeConnections');

    final buffer = StringBuffer();
    double? finalTps;
    TurnMetrics? turnMetrics;

    try {
      await for (final token in stream.timeout(
        streamIdleTimeout,
        onTimeout: (sink) => sink.addError(
          LLMEngineException('Timeout: motor sin emitir tokens por ${streamIdleTimeout.inSeconds}s'),
        ),
      )) {
        if (!isGenerationCurrent(generationId, isMounted())) break;
        if (token.phase == 'model_loading') onPhaseChange(ModelConnectionState.loadingModel);
        if (token.stop) {
          finalTps = token.tps;
          if (token.timings != null) turnMetrics = TurnMetrics.fromJson(token.timings!);
          break;
        }
        buffer.write(token.content);
        scheduleStreamFlush(buffer, isMounted: isMounted, onFlush: onTextUpdated);
      }
    } finally {
      cancelStreamFlush();
    }

    return StreamTurnResult(fullText: buffer.toString().trim(), tps: finalTps, turnMetrics: turnMetrics);
  }

  /// Libera el lease cerrando el socket HTTP y decrementando conexiones activas.
  void releaseStream(StreamLease lease, String reason) {
    if (lease.released) return;
    lease.released = true;
    if (identical(_activeStream, lease)) _activeStream = null;
    if (_activeConnections > 0) _activeConnections--;
    try {
      lease.client.close();
      debugPrint('[ChatStreamSession] Cliente cerrado ($reason). Activas: $_activeConnections');
    } catch (e) {
      debugPrint('[ChatStreamSession] Error cerrando cliente ($reason): $e');
    }
  }

  /// Detiene la inferencia en curso emitiendo cancel cooperativo a llama.cpp.
  void stop({required LLMEngineClient engine}) {
    _generationCancelled = true;
    _activeGenerationId = null;
    cancelStreamFlush();
    final lease = _activeStream;
    if (lease != null) {
      unawaited(cancelCooperativo(engine, lease.requestId));
      releaseStream(lease, 'stop');
    }
  }

  /// Cancela la solicitud en nanortime mediante POST /cancel.
  Future<void> cancelCooperativo(LLMEngineClient engine, String requestId) async {
    try {
      final ok = await engine.cancelRequest(requestId);
      debugPrint('[ChatStreamSession] cancel $requestId ${ok ? "confirmado" : "no encontrado"}');
    } catch (e) {
      debugPrint('[ChatStreamSession] cancel request error: $e');
    }
  }

  /// Sanea el texto delegando en StreamSanitizer (mantenimiento de compatibilidad).
  static String sanitizeGeneratedText(String raw) => StreamSanitizer.sanitize(raw);

  /// Limpia recursos al destruir el notifier para evitar fugas de sockets.
  void dispose() {
    _generationCancelled = true;
    _activeGenerationId = null;
    cancelStreamFlush();
    final lease = _activeStream;
    if (lease != null) releaseStream(lease, 'dispose');
    if (_activeConnections > 0) {
      debugPrint('[ChatStreamSession] WARNING: $_activeConnections conexiones en dispose');
    }
  }
}
