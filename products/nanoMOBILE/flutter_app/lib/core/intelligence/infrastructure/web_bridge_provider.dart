import 'dart:async';
import '../domain/ai_provider.dart';

/// Proveedor de Inteligencia Web/PC Bridge (ChatGPT, Claude, Gemini Web via MCP Bridge).
///
/// Permite consultar modelos web alojados en una sesión activa de navegador
/// en el PC mediante transporte remoto MCP/WebSocket sin exponer credenciales.
class WebBridgeProvider implements IAiProvider {
  WebBridgeProvider({
    required this.serviceName,
    this.bridgeHost = '127.0.0.1',
    this.bridgePort = 8765,
    this.isConnected = false,
  });

  final String serviceName; // 'ChatGPT Web', 'Claude Web', 'Gemini Web'
  final String bridgeHost;
  final int bridgePort;
  final bool isConnected;

  @override
  String get name => serviceName;

  @override
  AiProviderKind get kind => AiProviderKind.webBridge;

  @override
  Future<bool> isAvailable() async {
    // Si la conexión al bridge está activa o el host es accesible
    return isConnected;
  }

  @override
  Future<AiProviderResponse> sendPrompt(
    String prompt, {
    Map<String, dynamic> options = const {},
  }) async {
    if (!isConnected) {
      return AiProviderResponse(
        text: '[WebBridge] El puente PC hacia $serviceName no está conectado en este momento.',
        providerName: name,
        kind: kind,
      );
    }
    // En una iteración futura conecta con el socket del PC Bridge
    return AiProviderResponse(
      text: '[WebBridge Response de $serviceName para: "$prompt"]',
      providerName: name,
      kind: kind,
    );
  }

  @override
  Stream<String> streamPrompt(
    String prompt, {
    Map<String, dynamic> options = const {},
  }) async* {
    final res = await sendPrompt(prompt, options: options);
    yield res.text;
  }
}
