part of 'litert_inference_adapter.dart';

// Un controlador por requestId administra eventos terminales, fallos y cierre nativo.
extension LiteRtStreaming on LiteRtInferenceAdapter {
  Stream<LLMStreamToken> generateTokens({
    required String prompt,
    double temperature = 0.3,
    double topP = 0.95,
    int maxTokens = 512,
    String? sessionId,
    String? context,
    List<Map<String, String>>? history,
    required String requestId,
  }) {
    StreamSubscription<dynamic>? subscription;
    late StreamController<LLMStreamToken> controller;
    var finished = false;
    final budget = ExecutionBudget.current;
    void Function()? detachBudget;
    Future<void> finish([Object? error, LLMStreamToken? terminal]) async {
      if (finished) return;
      finished = true;
      detachBudget?.call();
      if (error != null) {
        // Un fallo del canal sí aborta JNI; no deja generación sin receptor.
        unawaited(cancel(requestId).catchError((Object _) => false));
        if (!controller.isClosed) controller.addError(error);
      }
      await subscription?.cancel();
      // Cierra el receptor anterior ANTES de admitir otra suscripción nativa.
      // Publica stop con la reserva ya libre, no durante ese cierre asíncrono.
      if (_requestId == requestId) _requestId = null;
      if (terminal != null && !controller.isClosed) controller.add(terminal);
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
              final token = LLMStreamToken(
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
              );
              if (stop) {
                unawaited(finish(null, token));
              } else {
                controller.add(token);
              }
            }, onError: (Object error) => unawaited(finish(error)));
        try {
          // La cancelación conserva el requestId: no afecta otro chat o motor.
          detachBudget = budget?.register(() {
            unawaited(cancel(requestId).catchError((Object _) => false));
          });
          await LiteRtInferenceAdapter._channel.invokeMethod('generate', {
            'requestId': requestId,
            'prompt': prompt,
            'sessionId': sessionId,
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
        final needsNativeCancel = !finished;
        detachBudget?.call();
        finished = true;
        // Cerrar un stream completado no es una orden de abortar su sesión JNI.
        if (needsNativeCancel) await cancel(requestId);
        await subscription?.cancel();
        if (_requestId == requestId) _requestId = null;
      },
    );
    return controller.stream;
  }
}
