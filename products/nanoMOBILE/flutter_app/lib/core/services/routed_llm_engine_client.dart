// QUÉ: router único de llama.cpp/HTTP, LiteRT/JNI y MNN/JNI para chat y automatización.
// CÓMO: evalúa el motor activo por llamada y consulta readiness nativo real.
// POR QUÉ: conserva prompts, historial y permisos sin duplicar transportes.
// El perfil MNN es texto: rechaza medios no soportados en vez de simularlos.

import 'dart:async';
import 'package:http/http.dart' as http;
import 'llm_engine_client.dart';
import 'litert_inference_adapter.dart';
import 'mnn_inference_adapter.dart';
import 'inference_media_input.dart';
part 'routed_native_generation.dart';

class RoutedLlmEngineClient extends LLMEngineClient {
  final LLMEngineClient llama;
  final LiteRtInferenceAdapter liteRt;
  final MnnInferenceAdapter mnn;
  final bool Function() useLiteRt;
  final bool Function() useMnn;

  RoutedLlmEngineClient({
    required this.llama,
    required this.liteRt,
    required this.mnn,
    required this.useLiteRt,
    required this.useMnn,
  });

  // MNN tardó 111 s hasta el primer token medido en el CPH2557; 180 s evita un falso timeout durante prefill.
  @override
  Duration get streamIdleTimeout =>
      useMnn() ? const Duration(seconds: 180) : super.streamIdleTimeout;

  @override
  bool get hasActiveStreamRequest {
    if (useLiteRt()) return liteRt.hasActiveRequest;
    if (useMnn()) return mnn.hasActiveRequest;
    return llama.hasActiveStreamRequest;
  }

  @override
  Future<bool> isOnline({
    int attempts = 5,
    Duration requestTimeout = const Duration(seconds: 5),
  }) {
    if (useLiteRt()) return liteRt.isReady();
    if (useMnn()) return mnn.isReady();
    return llama.isOnline(attempts: attempts, requestTimeout: requestTimeout);
  }

  @override
  Future<bool> hasModel() {
    if (useLiteRt()) return liteRt.isReady();
    if (useMnn()) return mnn.isReady();
    return llama.hasModel();
  }

  @override
  Future<RuntimeStatus> getStatus() {
    if (useLiteRt()) {
      return Future.error(
        LLMEngineException('LiteRT no expone el status HTTP de llama.cpp'),
      );
    }
    if (useMnn()) {
      return Future.error(
        LLMEngineException('MNN no expone el status HTTP de llama.cpp'),
      );
    }
    return llama.getStatus();
  }

  @override
  Future<bool> cancelRequest(String requestId) {
    if (useLiteRt()) return liteRt.cancel(requestId);
    if (useMnn()) return mnn.cancel(requestId);
    return llama.cancelRequest(requestId);
  }

  @override
  Future<LLMResult> generate({
    required String prompt,
    double temperature = 0.7,
    int maxTokens = 256,
    String? sessionId,
    String? context,
    List<Map<String, String>>? history,
    Duration? requestTimeout,
    List<InferenceMediaInput> mediaInputs = const [],
  }) async {
    if (useLiteRt()) {
      return _generateLiteRt(
        prompt: prompt,
        temperature: temperature,
        maxTokens: maxTokens,
        sessionId: sessionId,
        context: context,
        history: history,
        requestTimeout: requestTimeout,
      );
    }
    if (useMnn()) {
      return _generateMnn(
        prompt: prompt,
        temperature: temperature,
        maxTokens: maxTokens,
        context: context,
        history: history,
        requestTimeout: requestTimeout,
        mediaInputs: mediaInputs,
      );
    }
    return llama.generate(
      prompt: prompt,
      temperature: temperature,
      maxTokens: maxTokens,
      sessionId: sessionId,
      context: context,
      history: history,
      requestTimeout: requestTimeout,
      mediaInputs: mediaInputs,
    );
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
    List<InferenceMediaInput> mediaInputs = const [],
  }) {
    if (useLiteRt()) {
      final id = requestId ?? LLMEngineClient.newRequestId();
      return (
        stream: liteRt.generateTokens(
          prompt: prompt,
          temperature: temperature,
          topP: topP,
          maxTokens: maxTokens,
          sessionId: sessionId,
          context: context,
          history: history,
          requestId: id,
        ),
        client: _NativeCancellationLease(() => liteRt.cancel(id)),
        requestId: id,
      );
    }
    if (useMnn()) {
      final id = requestId ?? LLMEngineClient.newRequestId();
      return (
        stream: mnn.generateTokens(
          prompt: prompt,
          temperature: temperature,
          topP: topP,
          maxTokens: maxTokens,
          context: context,
          history: history,
          mediaInputs: mediaInputs,
          requestId: id,
        ),
        client: _NativeCancellationLease(() => mnn.cancel(id)),
        requestId: id,
      );
    }
    return llama.generateStream(
      prompt: prompt,
      temperature: temperature,
      topP: topP,
      maxTokens: maxTokens,
      sessionId: sessionId,
      context: context,
      history: history,
      requestId: requestId,
      mediaInputs: mediaInputs,
    );
  }

  @override
  void dispose() {
    llama.dispose();
    super.dispose();
  }
}
