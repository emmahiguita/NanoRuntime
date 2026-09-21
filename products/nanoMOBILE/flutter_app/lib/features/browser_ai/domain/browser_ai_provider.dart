import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'browser_ai_response.dart';

/// QUÉ HACE:
/// Contrato de interfaz formal para cualquier proveedor web de chat con IA.
///
/// CÓMO FUNCIONA:
/// Define los métodos necesarios para validar sesión, inyectar prompts en el DOM
/// y observar la estabilización del texto en la página mediante el [InAppWebViewController].
///
/// POR QUÉ:
/// Cumple el principio Abierto/Cerrado (OCP): se pueden añadir nuevos chats de IA
/// (Mistral, Perplexity, etc.) sin modificar el núcleo de BrowserAiGateway.
abstract interface class BrowserAiProvider {
  /// Identificador único del proveedor (ej: 'chatgpt', 'gemini', 'claude', 'deepseek').
  String get id;

  /// Nombre visible para el usuario en la interfaz.
  String get displayName;

  /// URL inicial oficial del servicio web.
  Uri get defaultUrl;

  /// Determina si una URL pertenece al dominio de este proveedor.
  bool canHandle(Uri url);

  /// Verifica en el DOM si el usuario tiene una sesión iniciada activa.
  Future<bool> isLoggedIn(InAppWebViewController controller);

  /// Localiza el campo de entrada semántico e inyecta y envía el prompt.
  Future<bool> submitPrompt(
    InAppWebViewController controller,
    String prompt,
  );

  /// Cuenta los mensajes existentes en el DOM antes de enviar una consulta.
  Future<int> countMessages(InAppWebViewController controller);

  /// Observa la generación de la respuesta hasta su estabilización o timeout.
  Future<BrowserAiResponse> waitForResponse(
    InAppWebViewController controller,
    Duration timeout, {
    int baselineCount = 0,
    String? requestId,
  });
}
