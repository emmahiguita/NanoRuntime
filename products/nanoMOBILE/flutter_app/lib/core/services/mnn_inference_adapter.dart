// QUÉ HACE: Adaptador Flutter para MNN-LLM. Gestiona el ciclo de vida y streaming de tokens.
// CÓMO FUNCIONA: Usa MethodChannel para comandos (load/generate/cancel/unload) y EventChannel para streaming.
// POR QUÉ: Permite incorporar Qwen2.5-Omni 3B como tercer motor independiente respetando SOLID.
import 'dart:async';
import 'execution_budget.dart';
import 'package:flutter/services.dart';
import 'generative_inference_port.dart';
import 'llm_engine_client.dart';
import 'inference_media_input.dart';
part 'mnn_stream_lifecycle.dart';

class MnnInferenceAdapter implements GenerativeInferencePort {
  static const _methods = MethodChannel('com.nanoai/mnn');
  static const _events = EventChannel('com.nanoai/mnn_events');
  final _pending = <String, StreamController<LLMStreamToken>>{};
  StreamSubscription<dynamic>? _eventSubscription;
  String? _modelPath, _requestedPath;

  @override
  String get providerId => 'local_mnn';

  @override
  bool get isConfigured => _modelPath != null;
  bool get hasActiveRequest => _pending.isNotEmpty;
  Map<String, dynamic> lastMetrics = const {};

  // El otro engine Flutter puede reemplazar el modelo: valida el dueño nativo real.
  Future<bool> isReady() async {
    final status = await _methods.invokeMapMethod<String, dynamic>('status');
    return status?['loaded'] == true && status?['modelPath'] == _modelPath;
  }

  // One EventChannel subscription is shared so concurrent requests cannot steal events.
  void _listenOnce() {
    _eventSubscription ??= _events.receiveBroadcastStream().listen(
      _receive,
      onError: _failAll,
    );
  }

  void _receive(dynamic value) {
    if (value is! Map) return;
    final id = value['requestId']?.toString();
    final sink = id == null ? null : _pending[id];
    if (sink != null && value['error'] != null) {
      sink.addError(StateError(value['error'].toString()));
      return;
    }
    if (sink == null || value['token'] == null) return;
    sink.add(LLMStreamToken(content: value['token'].toString(), stop: false));
  }

  void _failAll(Object error, [StackTrace? trace]) {
    for (final stream in _pending.values) {
      stream.addError(error, trace);
      unawaited(stream.close());
    }
    _pending.clear();
  }

  Future<bool> initialize({
    required String modelPath,
    String backend = 'cpu',
  }) async {
    if (backend != 'cpu') {
      throw ArgumentError('MNN inicia en CPU hasta medir otra ruta.');
    }
    // Reutiliza únicamente pesos confirmados para este canal y la misma selección.
    if (_requestedPath == modelPath && await isReady()) return true;
    if (!await release()) throw StateError('MNN no confirmó la liberación');
    final ready = await _methods.invokeMethod<bool>('load', {
      'modelPath': modelPath,
    });
    if (ready != true) return false;
    final status = await _methods.invokeMapMethod<String, dynamic>('status');
    // JNI normaliza alias Android; readiness compara esa ruta, no la entrada original.
    _requestedPath = modelPath;
    _modelPath = status?['loaded'] == true
        ? (status?['modelPath'] as String?)
        : null;
    return _modelPath != null;
  }

  // Implementación del puerto GenerativeInferencePort para consumo unificado en la app.
  @override
  Future<String?> generate({
    required String prompt,
    double temperature = 0.3,
    int maxTokens = 320,
  }) async {
    final buffer = StringBuffer();
    final id = LLMEngineClient.newRequestId();
    await for (final token in generateTokens(
      prompt: prompt,
      requestId: id,
      temperature: temperature,
      maxTokens: maxTokens,
    )) {
      if (!token.stop) buffer.write(token.content);
    }
    return buffer.toString();
  }

  Future<bool> cancel(String requestId) async =>
      await _methods.invokeMethod<bool>('cancel', {'requestId': requestId}) ??
      false;

  Future<bool> release() async {
    if (hasActiveRequest) await cancel(_pending.keys.first);
    final released = await _methods.invokeMethod<bool>('unload') ?? true;
    if (released) {
      _modelPath = null;
      _requestedPath = null;
    }
    return released;
  }

  void dispose() {
    unawaited(release());
    unawaited(_eventSubscription?.cancel());
    _eventSubscription = null;
  }
}
