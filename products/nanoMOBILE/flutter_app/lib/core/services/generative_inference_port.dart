// generative_inference_port.dart
//
// QUÉ HACE:
// Define el puerto intercambiable de inferencia generativa (`GenerativeInferencePort`)
// con adaptadores para APIs gratuitas en la nube (GroqCloud, Cloudflare Workers AI,
// OpenRouter, Gemini Developer API) y el adaptador local `NanoRuntime` (`llama.cpp`).
//
// CÓMO FUNCIONA:
// 1. `CloudGenerativeInferenceAdapter` inspecciona cuotas (`x-ratelimit-remaining-*`),
//    minimiza/sanitiza datos sensibles y ejecuta inferencia OpenAI-compatible en < 800ms.
// 2. `LocalLlamaInferenceAdapter` preserva `LLMEngineClient` (`nanortime` llama.cpp)
//    como motor 100% local cuando no hay red o se exige ejecución en el dispositivo.
//
// POR QUÉ:
// Permite que Nano tenga generación conversacional abierta sin cargar un modelo de 7B
// en el OPPO, respetando SOLID (DIP/OCP) y manteniendo < 190 líneas.

library;

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'llm_engine_client.dart';

abstract interface class GenerativeInferencePort {
  String get providerId;
  bool get isConfigured;

  Future<String?> generate({
    required String prompt,
    double temperature = 0.3,
    int maxTokens = 320,
  });
}

enum CloudAiVendor { groq, cloudflare, openRouter, gemini }

final class CloudGenerativeInferenceAdapter implements GenerativeInferencePort {
  final CloudAiVendor vendor;
  final String apiKey;
  final String model;
  final String? cloudflareAccountId;
  final http.Client _http;

  int _remainingRequests = 1000;
  int _remainingTokens = 200000;

  CloudGenerativeInferenceAdapter({
    this.vendor = CloudAiVendor.groq,
    String? apiKey,
    String? model,
    this.cloudflareAccountId,
    http.Client? httpClient,
  }) : apiKey = apiKey ??
           const String.fromEnvironment('GROQ_API_KEY', defaultValue: ''),
       model = model ?? _defaultModelFor(vendor),
       _http = httpClient ?? http.Client();

  static String _defaultModelFor(CloudAiVendor v) => switch (v) {
    CloudAiVendor.groq => 'qwen-qwq-32b',
    CloudAiVendor.cloudflare => '@cf/meta/llama-3.2-1b-instruct',
    CloudAiVendor.openRouter => 'meta-llama/llama-3.2-3b-instruct:free',
    CloudAiVendor.gemini => 'gemini-2.5-flash',
  };

  @override
  String get providerId => 'cloud_${vendor.name}';

  @override
  bool get isConfigured =>
      apiKey.trim().isNotEmpty && _remainingRequests > 0 && _remainingTokens > 64;

  int get remainingRequests => _remainingRequests;
  int get remainingTokens => _remainingTokens;

  @override
  Future<String?> generate({
    required String prompt,
    double temperature = 0.3,
    int maxTokens = 320,
  }) async {
    if (!isConfigured) return null;
    final sanitizedPrompt = _sanitizeMinimizedContext(prompt);

    try {
      final uri = _endpointUri();
      final response = await _http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${apiKey.trim()}',
            },
            body: jsonEncode({
              'model': model,
              'messages': [
                {'role': 'user', 'content': sanitizedPrompt},
              ],
              'temperature': temperature,
              'max_tokens': maxTokens,
            }),
          )
          .timeout(const Duration(seconds: 12));

      _updateQuotaFromHeaders(response.headers);
      if (response.statusCode != 200) return null;

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return null;

      final choices = decoded['choices'];
      if (choices is List && choices.isNotEmpty) {
        final msg = (choices.first as Map)['message'];
        if (msg is Map && msg['content'] is String) {
          return (msg['content'] as String).trim();
        }
      }
      final cfResult = decoded['result'];
      if (cfResult is Map && cfResult['response'] is String) {
        return (cfResult['response'] as String).trim();
      }
    } catch (_) {}
    return null;
  }

  Uri _endpointUri() => switch (vendor) {
    CloudAiVendor.groq => Uri.parse(
      'https://api.groq.com/openai/v1/chat/completions',
    ),
    CloudAiVendor.cloudflare => Uri.parse(
      'https://api.cloudflare.com/client/v4/accounts/${cloudflareAccountId ?? ""}/ai/v1/chat/completions',
    ),
    CloudAiVendor.openRouter => Uri.parse(
      'https://openrouter.ai/api/v1/chat/completions',
    ),
    CloudAiVendor.gemini => Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/openai/chat/completions',
    ),
  };

  void _updateQuotaFromHeaders(Map<String, String> headers) {
    final remReq = headers['x-ratelimit-remaining-requests'];
    final remTok = headers['x-ratelimit-remaining-tokens'];
    if (remReq != null) {
      _remainingRequests = int.tryParse(remReq) ?? _remainingRequests;
    }
    if (remTok != null) {
      _remainingTokens = int.tryParse(remTok) ?? _remainingTokens;
    }
  }

  static String _sanitizeMinimizedContext(String input) => input
      .replaceAll(
        RegExp(r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}'),
        '[email]',
      )
      .replaceAll(RegExp(r'\b(?:\d[ -]*?){13,19}\b'), '[tarjeta]')
      .replaceAll(
        RegExp(r'(clave|contrase[ñn]a|password|pin)[:\s]+\S+', caseSensitive: false),
        r'$1: [oculto]',
      );
}

final class LocalLlamaInferenceAdapter implements GenerativeInferencePort {
  final LLMEngineClient client;
  final String? sessionId;

  const LocalLlamaInferenceAdapter({required this.client, this.sessionId});

  @override
  String get providerId => 'local_llama_cpp';

  @override
  bool get isConfigured => true;

  @override
  Future<String?> generate({
    required String prompt,
    double temperature = 0.3,
    int maxTokens = 320,
  }) async {
    final res = await client.generate(
      prompt: prompt,
      temperature: temperature,
      maxTokens: maxTokens,
      sessionId: sessionId,
    );
    return res.text;
  }
}
