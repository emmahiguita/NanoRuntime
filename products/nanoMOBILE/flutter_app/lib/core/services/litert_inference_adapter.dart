// litert_inference_adapter.dart
// QUÉ HACE: Adaptador cliente para el runtime nativo LiteRT-LM (Google AI Edge).
// CÓMO FUNCIONA: Comunica con Android vía MethodChannel/EventChannel para inferencia de modelos .litertlm.
// POR QUÉ: Permite evaluar LiteRT-LM (CPU/GPU OpenCL) con la misma interfaz abstracta que llama.cpp y Cloud.
library;

import 'dart:async';
import 'package:flutter/services.dart';
import 'generative_inference_port.dart';

/// Métricas de rendimiento registradas por LiteRT-LM.
class LiteRtMetrics {
  final int ttftMs;
  final double tokensPerSec;
  final int totalTokens;
  final int availMemMb;
  final String activeBackend;

  const LiteRtMetrics({
    this.ttftMs = 0,
    this.tokensPerSec = 0.0,
    this.totalTokens = 0,
    this.availMemMb = 0,
    this.activeBackend = 'cpu',
  });

  factory LiteRtMetrics.fromMap(Map<dynamic, dynamic> map) => LiteRtMetrics(
    ttftMs: (map['lastTtftMs'] as num?)?.toInt() ?? 0,
    tokensPerSec: (map['lastTokensPerSec'] as num?)?.toDouble() ?? 0.0,
    totalTokens: (map['lastTotalTokens'] as num?)?.toInt() ?? 0,
    availMemMb: (map['availMemMb'] as num?)?.toInt() ?? 0,
    activeBackend: map['activeBackend']?.toString() ?? 'cpu',
  );
}

/// Adaptador concreto de GenerativeInferencePort para LiteRT-LM.
final class LiteRtInferenceAdapter implements GenerativeInferencePort {
  static const MethodChannel _channel = MethodChannel('com.nanoai/litert');
  static const EventChannel _streamChannel = EventChannel('com.nanoai/litert_stream');

  String? _currentModelPath;
  String _currentBackend = 'cpu';
  bool _initialized = false;
  LiteRtMetrics _lastMetrics = const LiteRtMetrics();

  @override
  String get providerId => 'local_litert_lm';

  @override
  bool get isConfigured => _initialized && _currentModelPath != null;

  bool get isInitialized => _initialized;
  String get currentBackend => _currentBackend;
  String? get currentModelPath => _currentModelPath;
  LiteRtMetrics get lastMetrics => _lastMetrics;

  /// QUÉ HACE: Consulta al sistema Android si LiteRT y OpenCL están disponibles.
  Future<Map<String, dynamic>> checkAvailability() async {
    try {
      final res = await _channel.invokeMapMethod<String, dynamic>('isAvailable');
      return res ?? const {'supported': false, 'hasGpuOpenCl': false};
    } catch (_) {
      return const {'supported': false, 'hasGpuOpenCl': false};
    }
  }

  /// QUÉ HACE: Inicializa un modelo .litertlm especificando backend (cpu, gpu, npu).
  /// CÓMO FUNCIONA: Llama al método initialize en Kotlin que precarga pesos y configura cache.
  Future<bool> initialize({
    required String modelPath,
    String backend = 'cpu',
  }) async {
    try {
      final res = await _channel.invokeMapMethod<String, dynamic>('initialize', {
        'modelPath': modelPath,
        'backend': backend,
      });
      _initialized = res?['success'] == true;
      if (_initialized) {
        _currentModelPath = modelPath;
        _currentBackend = backend;
      }
      return _initialized;
    } catch (e) {
      _initialized = false;
      return false;
    }
  }

  /// QUÉ HACE: Genera texto completo esperando la finalización.
  @override
  Future<String?> generate({
    required String prompt,
    double temperature = 0.3,
    int maxTokens = 512,
  }) async {
    if (!isConfigured) return null;
    try {
      final res = await _channel.invokeMapMethod<String, dynamic>('generate', {
        'prompt': prompt,
        'temperature': temperature,
        'maxTokens': maxTokens,
      });
      if (res != null) {
        _lastMetrics = LiteRtMetrics(
          ttftMs: (res['ttftMs'] as num?)?.toInt() ?? 0,
          tokensPerSec: (res['tokensPerSec'] as num?)?.toDouble() ?? 0.0,
          totalTokens: (res['totalTokens'] as num?)?.toInt() ?? 0,
          activeBackend: _currentBackend,
        );
        return res['text'] as String?;
      }
    } catch (_) {}
    return null;
  }

  /// QUÉ HACE: Emite tokens de forma incremental en streaming para latencia percibida baja.
  Stream<String> generateStream({
    required String prompt,
    double temperature = 0.3,
    int maxTokens = 512,
  }) {
    if (!isConfigured) return const Stream.empty();
    _channel.invokeMethod('generate', {
      'prompt': prompt,
      'temperature': temperature,
      'maxTokens': maxTokens,
    });

    return _streamChannel
        .receiveBroadcastStream()
        .map((event) => event.toString());
  }

  /// QUÉ HACE: Descarga el modelo de la memoria nativa y libera RAM de inmediato.
  Future<bool> release() async {
    try {
      final ok = await _channel.invokeMethod<bool>('release');
      _initialized = false;
      _currentModelPath = null;
      return ok ?? true;
    } catch (_) {
      _initialized = false;
      return false;
    }
  }

  /// QUÉ HACE: Recupera estadísticas en tiempo real de RAM del dispositivo y del motor.
  Future<LiteRtMetrics> fetchMetrics() async {
    try {
      final map = await _channel.invokeMapMethod<dynamic, dynamic>('getMetrics');
      if (map != null) {
        _lastMetrics = LiteRtMetrics.fromMap(map);
      }
    } catch (_) {}
    return _lastMetrics;
  }
}
