// QUÉ HACE: Adaptador Flutter para MNN-LLM. Gestiona el ciclo de vida y streaming de tokens.
// CÓMO FUNCIONA: Usa MethodChannel para comandos (load/generate/cancel/unload) y EventChannel para streaming.
// POR QUÉ: Permite incorporar Qwen2.5-Omni 3B como tercer motor independiente respetando SOLID.
import 'dart:async';
import 'package:flutter/services.dart';
import 'generative_inference_port.dart';
import 'llm_engine_client.dart';
import 'inference_media_input.dart';

class MnnInferenceAdapter implements GenerativeInferencePort {
  static const _methods = MethodChannel('com.nanoai/mnn');
  static const _events = EventChannel('com.nanoai/mnn_events');
  final _pending = <String, StreamController<LLMStreamToken>>{};
  StreamSubscription<dynamic>? _eventSubscription;
  String? _modelPath;

  @override
  String get providerId => 'local_mnn';

  @override
  bool get isConfigured => _modelPath != null;
  bool get hasActiveRequest => _pending.isNotEmpty;
  Map<String, dynamic> lastMetrics = const {};

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
    await release();
    final ready = await _methods.invokeMethod<bool>('load', {
      'modelPath': modelPath,
    });
    _modelPath = ready == true ? modelPath : null;
    return ready == true;
  }

  // Adapta roles y archivos reales al chat-template Omni oficial de Qwen.
  String _chatMl(
    String prompt,
    String? system,
    List<Map<String, String>>? history,
    List<InferenceMediaInput> media,
  ) {
    final out = StringBuffer();
    void message(String role, String text) =>
        out.write('<|im_start|>$role\n$text<|im_end|>\n');
    message('system', system ?? '');
    for (final turn in history ?? const []) {
      final role = turn['role'];
      if (role == 'user' || role == 'assistant') {
        message(role!, turn['content'] ?? '');
      }
    }
    final user = StringBuffer(prompt);
    for (final input in media) {
      if (input.path.isEmpty) continue;
      final tag = input.type == 'image'
          ? 'img'
          : input.type == 'audio'
          ? 'audio'
          : null;
      if (tag != null) user.write('\n<$tag>${input.path}</$tag>');
    }
    out.write('<|im_start|>user\n$user<|im_end|>\n<|im_start|>assistant\n');
    return out.toString();
  }

  // A request has one native owner; closing its stream signals cancel and waits for native completion.
  Stream<LLMStreamToken> generateTokens({
    required String prompt,
    required String requestId,
    double temperature = 0.7,
    double topP = 0.9,
    String? context,
    List<Map<String, String>>? history,
    List<InferenceMediaInput> mediaInputs = const [],
    int maxTokens = 256,
  }) {
    // El paquete configurado en Android usa llm_config.json de texto, no el grafo Omni multimodal.
    if (mediaInputs.isNotEmpty) {
      throw UnsupportedError(
        'Este perfil MNN admite texto; imagen y audio requieren un paquete multimodal activo.',
      );
    }
    _listenOnce();
    late final StreamController<LLMStreamToken> stream;
    stream = StreamController<LLMStreamToken>(
      onListen: () {
        if (!isConfigured) {
          stream.addError(StateError('MNN no tiene un modelo cargado.'));
          unawaited(stream.close());
          return;
        }
        if (_pending.isNotEmpty) {
          stream.addError(StateError('MNN admite una generación a la vez.'));
          unawaited(stream.close());
          return;
        }
        _pending[requestId] = stream;
        _methods
            .invokeMapMethod<String, dynamic>('generate', {
              'requestId': requestId,
              'prompt': _chatMl(prompt, context, history, mediaInputs),
              // Reenvía los controles que el router antes descartaba.
              'temperature': temperature,
              'topP': topP,
              'maxTokens': maxTokens,
            })
            .then(
              (metrics) {
                lastMetrics = metrics ?? const {};
                stream.add(
                  LLMStreamToken(
                    content: '',
                    stop: true,
                    tps: (lastMetrics['decode_tok_s'] as num?)?.toDouble(),
                    timings: lastMetrics,
                  ),
                );
                _pending.remove(requestId);
                unawaited(stream.close());
              },
              onError: (Object error, StackTrace trace) {
                _pending.remove(requestId);
                stream.addError(error, trace);
                unawaited(stream.close());
              },
            );
      },
      onCancel: () {
        if (_pending.remove(requestId) != null) unawaited(cancel(requestId));
      },
    );
    return stream.stream;
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
    if (released) _modelPath = null;
    return released;
  }

  void dispose() {
    unawaited(release());
    unawaited(_eventSubscription?.cancel());
    _eventSubscription = null;
  }
}
