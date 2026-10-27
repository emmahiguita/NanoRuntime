part of 'mnn_inference_adapter.dart';

// Streaming y plantilla reutilizan el adaptador: no crean otro dueño JNI.
extension MnnStreaming on MnnInferenceAdapter {
  // La plantilla ChatML pertenece al runtime nativo (jinja en MNN). Dart solo
  // entrega mensajes estructurados con roles; el nativo aplica el template,
  // tokeniza y conserva el KV. Nunca ensamblar ChatML a mano en esta capa.

  // A request has one native owner; closing its stream signals cancel and waits for native completion.
  Stream<LLMStreamToken> generateTokens({
    required String prompt,
    required String requestId,
    String? sessionId,
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
    final budget = ExecutionBudget.current;
    void Function()? detachBudget;
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
        try {
          detachBudget = budget?.register(() {
            unawaited(cancel(requestId).catchError((Object _) => false));
          });
        } catch (error, trace) {
          stream.addError(error, trace);
          unawaited(stream.close());
          return;
        }
        _pending[requestId] = stream;
        MnnInferenceAdapter._methods
            .invokeMapMethod<String, dynamic>('generate', {
              'requestId': requestId,
              'sessionId': sessionId,
              // Mensajes estructurados: system + historial con roles + turno.
              // El nativo renderiza la plantilla del modelo y reutiliza KV.
              'system': context ?? '',
              'history': [
                for (final turn in history ?? const <Map<String, String>>[])
                  if (turn['role'] == 'user' || turn['role'] == 'assistant')
                    {'role': turn['role'], 'content': turn['content'] ?? ''},
              ],
              'prompt': prompt,
              // Reenvía los controles que el router antes descartaba.
              'temperature': temperature,
              'topP': topP,
              'maxTokens': maxTokens,
            })
            .then(
              (metrics) {
                detachBudget?.call();
                if (stream.isClosed) return;
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
                detachBudget?.call();
                _pending.remove(requestId);
                if (stream.isClosed) return;
                stream.addError(error, trace);
                unawaited(stream.close());
              },
            );
      },
      onCancel: () {
        detachBudget?.call();
        if (_pending.remove(requestId) != null) unawaited(cancel(requestId));
      },
    );
    return stream.stream;
  }
}
