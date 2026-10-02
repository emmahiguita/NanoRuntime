part of 'litert_inference_adapter.dart';

// Un controlador por requestId administra eventos terminales, fallos y cierre nativo.
extension LiteRtStreaming on LiteRtInferenceAdapter {
  Stream<LLMStreamToken> generateTokens({
    required String prompt,
    double temperature = 0.3,
    double topP = 0.95,
    int maxTokens = 512,
    String? context,
    List<Map<String, String>>? history,
    required String requestId,
  }) {
    StreamSubscription<dynamic>? subscription;
    late StreamController<LLMStreamToken> controller;
    var finished = false;
    Future<void> finish([Object? error]) async {
      if (finished) return;
      finished = true;
      if (error != null && !controller.isClosed) controller.addError(error);
      await subscription?.cancel();
      if (_requestId == requestId) _requestId = null;
      unawaited(controller.close());
    }

    controller = StreamController<LLMStreamToken>(
      onListen: () async {
        if (!isConfigured || hasActiveRequest) {
          await finish(
            LLMEngineException('LiteRT no está listo o ya está generando'),
          );
          return;
        }
        _requestId = requestId;
        _metrics = const LiteRtMetrics();
        subscription = LiteRtInferenceAdapter._events
            .receiveBroadcastStream()
            .listen((dynamic value) {
              if (value is! Map ||
                  value['requestId'] != requestId ||
                  finished) {
                return;
              }
              if (value['error'] != null) {
                unawaited(
                  finish(LLMEngineException(value['error'].toString())),
                );
                return;
              }
              final stop = value['stop'] == true;
              if (stop) _metrics = LiteRtMetrics.fromMap(value);
              controller.add(
                LLMStreamToken(
                  content: value['content'] as String? ?? '',
                  stop: stop,
                  phase: value['phase'] as String?,
                  tps: stop ? _metrics.tokensPerSec : null,
                  timings: stop
                      ? {
                          'ttft_ms': _metrics.ttftMs,
                          'decode_tok_s': _metrics.tokensPerSec,
                        }
                      : null,
                ),
              );
              if (stop) unawaited(finish());
            }, onError: (Object error) => unawaited(finish(error)));
        try {
          await LiteRtInferenceAdapter._channel.invokeMethod('generate', {
            'requestId': requestId,
            'prompt': prompt,
            'context': context,
            'history': history ?? [],
            'temperature': temperature,
            'topP': topP,
            'maxTokens': maxTokens,
          });
          if (!finished) {
            await finish(
              LLMEngineException('LiteRT finalizó sin evento terminal'),
            );
          }
        } catch (error) {
          await finish(LLMEngineException(error.toString()));
        }
      },
      onCancel: () async {
        await cancel(requestId);
        await subscription?.cancel();
        if (_requestId == requestId) _requestId = null;
      },
    );
    return controller.stream;
  }
}
