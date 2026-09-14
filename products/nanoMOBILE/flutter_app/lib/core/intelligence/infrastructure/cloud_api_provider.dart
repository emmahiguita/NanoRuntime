import 'package:nanoai/core/services/external_ai_provider.dart';
import '../domain/ai_provider.dart';

/// Proveedor de Inteligencia Cloud Directo (OpenAI, Anthropic, Gemini API).
class CloudApiProvider implements IAiProvider {
  CloudApiProvider({
    required this.providerName,
    required this.apiKey,
    this.model,
  }) {
    if (providerName.toLowerCase().contains('gemini')) {
      _underlying = GeminiAIProvider(apiKey: apiKey, model: model ?? 'gemini-2.5-flash');
    } else {
      _underlying = ChatGPTAIProvider(apiKey: apiKey, model: model ?? 'gpt-4o-mini');
    }
  }

  final String providerName;
  final String apiKey;
  final String? model;
  late final ILLMProvider _underlying;

  @override
  String get name => providerName;

  @override
  AiProviderKind get kind => AiProviderKind.cloudApi;

  @override
  Future<bool> isAvailable() async {
    return _underlying.isAvailable();
  }

  @override
  Future<AiProviderResponse> sendPrompt(
    String prompt, {
    Map<String, dynamic> options = const {},
  }) async {
    final result = await _underlying.generate(prompt: prompt);
    return AiProviderResponse(
      text: result.text,
      providerName: name,
      kind: kind,
      modelName: model,
    );
  }

  @override
  Stream<String> streamPrompt(
    String prompt, {
    Map<String, dynamic> options = const {},
  }) {
    return _underlying.stream(prompt: prompt);
  }
}
