import 'package:flutter/foundation.dart';

/// Clasificación de proveedores de Inteligencia en Nano AI.
enum AiProviderKind {
  /// Ejecución local en el chip del dispositivo (llama.cpp / GGUF).
  local,

  /// API Directa Cloud (OpenAI, Anthropic, Google Gemini API).
  cloudApi,

  /// Puente Web/PC (Sesiones Web de ChatGPT, Claude, Gemini via WebSocket/CDP).
  webBridge,

  /// Capacidades expuestas por otras aplicaciones Android via Mobile-MCP / AIDL.
  androidApp,
}

/// Respuesta tipada de un proveedor de inteligencia.
@immutable
class AiProviderResponse {
  const AiProviderResponse({
    required this.text,
    required this.providerName,
    required this.kind,
    this.tokensPerSecond,
    this.modelName,
    this.metadata = const {},
  });

  final String text;
  final String providerName;
  final AiProviderKind kind;
  final double? tokensPerSecond;
  final String? modelName;
  final Map<String, dynamic> metadata;
}

/// Contrato abstracto (DIP) que debe implementar todo proveedor de inteligencia en Nano AI.
abstract class IAiProvider {
  String get name;
  AiProviderKind get kind;
  Future<bool> isAvailable();

  /// Envia una solicitud de texto y retorna la respuesta procesada.
  Future<AiProviderResponse> sendPrompt(
    String prompt, {
    Map<String, dynamic> options = const {},
  });

  /// Streaming en vivo de la generación de tokens.
  Stream<String> streamPrompt(
    String prompt, {
    Map<String, dynamic> options = const {},
  });
}
