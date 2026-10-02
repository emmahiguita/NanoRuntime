// Conserva el contrato del chat y de Nano Personal: solo cambia el transporte local.
// El historial, prompts y permisos de herramientas pertenecen a sus casos de uso actuales.
import 'dart:async';
import 'package:http/http.dart' as http;
import 'llm_engine_client.dart';
import 'litert_inference_adapter.dart';

class RoutedLlmEngineClient extends LLMEngineClient {
  final LLMEngineClient llama;
  final LiteRtInferenceAdapter liteRt;
  final bool Function() useLiteRt;
  RoutedLlmEngineClient({
    required this.llama,
    required this.liteRt,
    required this.useLiteRt,
  });

  @override
  bool get hasActiveStreamRequest =>
      useLiteRt() ? liteRt.hasActiveRequest : llama.hasActiveStreamRequest;
  @override
  Future<bool> isOnline({
    int attempts = 5,
    Duration requestTimeout = const Duration(seconds: 5),
  }) => useLiteRt()
      ? Future.value(liteRt.isConfigured)
      : llama.isOnline(attempts: attempts, requestTimeout: requestTimeout);
  @override
  Future<bool> hasModel() =>
      useLiteRt() ? Future.value(liteRt.isConfigured) : llama.hasModel();
  @override
  Future<RuntimeStatus> getStatus() => useLiteRt()
      ? Future.error(
          LLMEngineException('LiteRT no expone el status HTTP de llama.cpp'),
        )
      : llama.getStatus();
  @override
  Future<bool> cancelRequest(String requestId) =>
      useLiteRt() ? liteRt.cancel(requestId) : llama.cancelRequest(requestId);

  @override
  Future<LLMResult> generate({
    required String prompt,
    double temperature = 0.7,
    int maxTokens = 256,
    String? sessionId,
    String? context,
    List<Map<String, String>>? history,
    Duration? requestTimeout,
  }) async {
    if (!useLiteRt()) {
      return llama.generate(
        prompt: prompt,
        temperature: temperature,
        maxTokens: maxTokens,
        sessionId: sessionId,
        context: context,
        history: history,
        requestTimeout: requestTimeout,
      );
    }
    final id = LLMEngineClient.newRequestId();
    final output = StringBuffer();
    try {
      // Límite total del turno: los latidos de progreso no deben reiniciar el plazo.
      await (() async {
        await for (final token in liteRt.generateTokens(
          prompt: prompt,
          temperature: temperature,
          maxTokens: maxTokens,
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

  @override
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
  }) {
    if (!useLiteRt()) {
      return llama.generateStream(
        prompt: prompt,
        temperature: temperature,
        topP: topP,
        maxTokens: maxTokens,
        sessionId: sessionId,
        context: context,
        history: history,
        requestId: requestId,
      );
    }
    final id = requestId ?? LLMEngineClient.newRequestId();
    return (
      stream: liteRt.generateTokens(
        prompt: prompt,
        temperature: temperature,
        topP: topP,
        maxTokens: maxTokens,
        context: context,
        history: history,
        requestId: id,
      ),
      client: _NativeCancellationLease(() => liteRt.cancel(id)),
      requestId: id,
    );
  }

  @override
  void dispose() {
    llama.dispose();
    super.dispose();
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
