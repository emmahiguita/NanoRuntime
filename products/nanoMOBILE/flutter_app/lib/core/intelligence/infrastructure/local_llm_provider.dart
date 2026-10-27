import '../../services/llm_engine_client.dart';
import '../domain/ai_provider.dart';

/// Adaptador al motor local real. El propietario inyecta el cliente configurado
/// y conserva su ciclo de vida; este proveedor no arranca otro proceso ni modelo.
/// Antes devolvía el propio prompt como respuesta: esa simulación se elimina.
class LocalLlamaProvider implements IAiProvider {
  const LocalLlamaProvider({
    required this.client,
    this.activeModelName = 'Local Nano AI',
  });
  final LLMEngineClient client;
  final String activeModelName;
  @override
  String get name => 'Local Engine';
  @override
  AiProviderKind get kind => AiProviderKind.local;

  /// Tener el runtime abierto no basta: debe existir un modelo cargado.
  @override
  Future<bool> isAvailable() async =>
      await client.isOnline(attempts: 1) && await client.hasModel();

  @override
  Future<AiProviderResponse> sendPrompt(
    String prompt, {
    Map<String, dynamic> options = const {},
  }) async {
    final result = await client.generate(
      prompt: prompt,
      temperature: _temperature(options),
      maxTokens: _tokens(options),
    );
    return AiProviderResponse(
      text: result.text,
      providerName: name,
      kind: kind,
      modelName: activeModelName,
      tokensPerSecond: result.tps,
    );
  }

  /// Transmite únicamente tokens del servidor. Cancelar el consumidor también
  /// solicita cancelar el cálculo; cerrar solo el socket puede dejar trabajo vivo.
  @override
  Stream<String> streamPrompt(
    String prompt, {
    Map<String, dynamic> options = const {},
  }) async* {
    final generation = client.generateStream(
      prompt: prompt,
      temperature: _temperature(options),
      maxTokens: _tokens(options),
    );
    var completed = false;
    try {
      await for (final token in generation.stream) {
        if (token.stop) completed = true;
        if (token.content.isNotEmpty) yield token.content;
      }
    } finally {
      try {
        if (!completed) await client.cancelRequest(generation.requestId);
      } finally {
        generation.client.close();
      }
    }
  }

  // Acota parámetros opcionales al contrato del cliente existente.
  int _tokens(Map<String, dynamic> values) =>
      ((values['maxTokens'] as num?)?.toInt() ?? 320).clamp(1, 2048);
  double _temperature(Map<String, dynamic> values) =>
      ((values['temperature'] as num?)?.toDouble() ?? .3).clamp(0.0, 2.0);
}
