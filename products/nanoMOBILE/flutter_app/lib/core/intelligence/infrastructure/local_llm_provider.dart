import 'dart:async';
import 'package:nanoai/core/services/nano_runtime_api.dart';
import '../domain/ai_provider.dart';

/// Proveedor de Inteligencia Local (GGUF / llama.cpp en dispositivo).
class LocalLlamaProvider implements IAiProvider {
  const LocalLlamaProvider({this.activeModelName = 'Local Nano AI'});

  final String activeModelName;

  @override
  String get name => 'Local Engine';

  @override
  AiProviderKind get kind => AiProviderKind.local;

  @override
  Future<bool> isAvailable() async {
    try {
      final info = await NanoRuntimeApi.instance.handshake();
      return info.available;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<AiProviderResponse> sendPrompt(
    String prompt, {
    Map<String, dynamic> options = const {},
  }) async {
    final buffer = StringBuffer();
    await for (final chunk in streamPrompt(prompt, options: options)) {
      buffer.write(chunk);
    }
    return AiProviderResponse(
      text: buffer.toString(),
      providerName: name,
      kind: kind,
      modelName: activeModelName,
    );
  }

  @override
  Stream<String> streamPrompt(
    String prompt, {
    Map<String, dynamic> options = const {},
  }) async* {
    yield prompt;
  }
}
