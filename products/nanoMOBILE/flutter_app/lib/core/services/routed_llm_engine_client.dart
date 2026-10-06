// routed_llm_engine_client.dart — Router de inferencia local para los 3 motores.
//
// QUÉ HACE:
// Enruta llamadas generativas (texto, streaming y multimedia) hacia el motor activo:
// 1. llama.cpp (GGUF vía proceso nativo nanortime y HTTP)
// 2. LiteRT-LM (Gemma / Qwen vía JNI)
// 3. MNN-LLM (Qwen2.5-Omni usando el perfil de texto activo en esta app)
//
// CÓMO FUNCIONA:
// Evalúa `useLiteRt()` y `useMnn()` en cada llamada. Cuando un motor local nativo
// está activo, deriva generación, streaming y cancelación sin sockets HTTP. El paquete
// MNN carga llm_config.json de texto; por eso el adaptador rechaza multimedia en vez de fingirla.
//
// POR QUÉ:
// Mantiene el contrato estándar de `LLMEngineClient` intacto para el chat y automatizaciones
// sin alterar historial, prompts ni permisos de herramientas. Mantiene el enrutamiento en un solo lugar.

import 'dart:async';
import 'package:http/http.dart' as http;
import 'llm_engine_client.dart';
import 'litert_inference_adapter.dart';
import 'mnn_inference_adapter.dart';
import 'inference_media_input.dart';

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
    if (useLiteRt()) return Future.value(liteRt.isConfigured);
    if (useMnn()) return Future.value(mnn.isConfigured);
    return llama.isOnline(attempts: attempts, requestTimeout: requestTimeout);
  }

  @override
  Future<bool> hasModel() {
    if (useLiteRt()) return Future.value(liteRt.isConfigured);
    if (useMnn()) return Future.value(mnn.isConfigured);
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
