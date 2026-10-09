// Puente de inferencia real. Suscribe eventos antes de generar y correlaciona cada turno.
// No oculta errores ni reemplaza métricas desconocidas por cifras estimadas.
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'execution_budget.dart';
import 'package:flutter/services.dart';
import 'generative_inference_port.dart';
import 'llm_engine_client.dart';
part 'litert_stream_lifecycle.dart';

class LiteRtMetrics {
  final int? ttftMs, totalTokens, durationMs;
  final double? tokensPerSec;
  final String? activeBackend;
  const LiteRtMetrics({
    this.ttftMs,
    this.totalTokens,
    this.durationMs,
    this.tokensPerSec,
    this.activeBackend,
  });
  factory LiteRtMetrics.fromMap(Map map) => LiteRtMetrics(
    ttftMs: (map['ttftMs'] as num?)?.toInt(),
    totalTokens: (map['totalTokens'] as num?)?.toInt(),
    durationMs: (map['durationMs'] as num?)?.toInt(),
    tokensPerSec: (map['tokensPerSec'] as num?)?.toDouble(),
    activeBackend: map['activeBackend'] as String?,
  );
}

final class LiteRtInferenceAdapter implements GenerativeInferencePort {
  static const _channel = MethodChannel('com.nanoai/litert');
  static const _events = EventChannel('com.nanoai/litert_stream');
  String? _path, _requestedPath, _backend, _requestId;
  LiteRtMetrics _metrics = const LiteRtMetrics();
  @override
  String get providerId => 'local_litert_lm';
  @override
  bool get isConfigured => _path != null;
  bool get isInitialized => isConfigured;
  String? get currentModelPath => _path;
  String? get currentBackend => _backend;
  bool get hasActiveRequest => _requestId != null;
  LiteRtMetrics get lastMetrics => _metrics;

  Future<Map<String, dynamic>> checkAvailability() async =>
      await _channel.invokeMapMethod<String, dynamic>('isAvailable') ??
      {'supported': false};

  // Consulta JNI: el supervisor puede haber liberado el modelo por inactividad.
  Future<bool> isReady() async {
    final status = await _channel.invokeMapMethod<String, dynamic>('status');
    // Registra solo identidad/estado, nunca el contenido privado de la conversación.
    debugPrint(
      '[LiteRT] loaded=${status?['loaded']} '
      'samePath=${status?['modelPath'] == _path} '
      'sameBackend=${status?['backend'] == _backend}',
    );
    return status?['loaded'] == true &&
        status?['modelPath'] == _path &&
        status?['backend'] == _backend;
  }

  // Solo declara éxito después de que Engine.initialize() haya terminado realmente.
  Future<bool> initialize({
    required String modelPath,
    String backend = 'gpu',
  }) async {
    if (_requestedPath == modelPath && _backend == backend && await isReady()) {
      return true;
    }
    _path = null;
    _requestedPath = null;
    _backend = null;
    final response = await _channel.invokeMapMethod<String, dynamic>(
      'initialize',
      {'modelPath': modelPath, 'backend': backend},
    );
    if (response?['success'] != true) return false;
    // Conserva el alias solicitado, pero readiness compara la identidad real de JNI.
    _requestedPath = modelPath;
    _path = response?['modelPath'] as String?;
    _backend = response?['backend'] as String?;
    return _path != null && _backend != null;
  }

  // La cancelación llega a Conversation.cancelProcess(), no solo al receptor visual.
  Future<bool> cancel(String id) async =>
      await _channel.invokeMethod<bool>('cancel', {'requestId': id}) ?? false;

  @override
  Future<String?> generate({
    required String prompt,
    double temperature = 0.3,
    int maxTokens = 320,
    String? sessionId,
  }) async {
    final buffer = StringBuffer();
    await for (final token in generateTokens(
      prompt: prompt,
      temperature: temperature,
      maxTokens: maxTokens,
      sessionId: sessionId,
      requestId: LLMEngineClient.newRequestId(),
    )) {
      if (!token.stop) buffer.write(token.content);
    }
    return buffer.toString();
  }

  Stream<String> generateStream({
    required String prompt,
    double temperature = 0.3,
    int maxTokens = 512,
    String? sessionId,
  }) => generateTokens(
    prompt: prompt,
    temperature: temperature,
    maxTokens: maxTokens,
    sessionId: sessionId,
    requestId: LLMEngineClient.newRequestId(),
  ).where((event) => !event.stop).map((event) => event.content);

  Future<bool> release() async {
    if (_requestId != null) await cancel(_requestId!);
    final ok = await _channel.invokeMethod<bool>('release') ?? false;
    if (ok) {
      _path = null;
      _requestedPath = null;
      _backend = null;
    }
    return ok;
  }

  Future<LiteRtMetrics> fetchMetrics() async {
    final result = await _channel.invokeMapMethod('getMetrics');
    if (result != null) _metrics = LiteRtMetrics.fromMap(result);
    return _metrics;
  }
}
