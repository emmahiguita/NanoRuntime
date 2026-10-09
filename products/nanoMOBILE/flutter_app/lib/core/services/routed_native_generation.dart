part of 'routed_llm_engine_client.dart';

// Generación nativa conserva un requestId cancelable y métricas reales del dueño activo.
extension _RoutedNativeGeneration on RoutedLlmEngineClient {
  Future<LLMResult> _generateLiteRt({
    required String prompt,
    required double temperature,
    required int maxTokens,
    String? sessionId,
    String? context,
    List<Map<String, String>>? history,
    Duration? requestTimeout,
  }) async {
    final id = LLMEngineClient.newRequestId();
    final output = StringBuffer();
    try {
      await (() async {
        await for (final token in liteRt.generateTokens(
          prompt: prompt,
          temperature: temperature,
          maxTokens: maxTokens,
          sessionId: sessionId,
          context: context,
          history: history,
          requestId: id,
        )) {
          if (!token.stop) output.write(token.content);
        }
      })().timeout(requestTimeout ?? timeout);
      return LLMResult(
        text: output.toString(),
        tps: liteRt.lastMetrics.tokensPerSec,
      );
    } on TimeoutException {
      await liteRt.cancel(id);
      throw LLMEngineException('LiteRT excedió el tiempo de respuesta');
    }
  }

  Future<LLMResult> _generateMnn({
    required String prompt,
    required double temperature,
    required int maxTokens,
    String? context,
    List<Map<String, String>>? history,
    Duration? requestTimeout,
    List<InferenceMediaInput> mediaInputs = const [],
  }) async {
    final id = LLMEngineClient.newRequestId();
    final output = StringBuffer();
    try {
      await (() async {
        await for (final token in mnn.generateTokens(
          prompt: prompt,
          temperature: temperature,
          maxTokens: maxTokens,
          context: context,
          history: history,
          mediaInputs: mediaInputs,
          requestId: id,
        )) {
          if (!token.stop) output.write(token.content);
        }
      })().timeout(requestTimeout ?? timeout);
      return LLMResult(
        text: output.toString(),
        tps: (mnn.lastMetrics['decode_tok_s'] as num?)?.toDouble(),
      );
    } on TimeoutException {
      await mnn.cancel(id);
      throw LLMEngineException('MNN excedió el tiempo de respuesta');
    }
  }
}

// Compatibilidad con StreamLease: cerrar este recurso cancela JNI, no crea una conexión HTTP ficticia.
class _NativeCancellationLease extends http.BaseClient {
  final Future<bool> Function() cancel;
  bool _closed = false;
  _NativeCancellationLease(this.cancel);
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      Future.error(StateError('Este lease solo administra cancelación nativa'));
  @override
  void close() {
    if (_closed) return;
    _closed = true;
    unawaited(cancel().then<void>((_) {}, onError: (Object _) {}));
  }
}
