import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../../domain/browser_ai_provider.dart';
import '../../domain/browser_ai_response.dart';
import '../browser_ai_dom_adapter.dart';

/// QUÉ HACE:
/// Proveedor de integración con Mistral AI (chat.mistral.ai) vía DOM.
///
/// CÓMO FUNCIONA:
/// Emplea selectores semánticos para el área de texto de Le Chat, despacha la
/// consulta y extrae el bloque de respuesta generado por los modelos Mistral Large / Pixtral.
///
/// POR QUÉ:
/// Ofrece una alternativa europea abierta y de alto rendimiento en razonamiento.
class MistralProvider implements BrowserAiProvider {
  final BrowserAiDomAdapter _adapter;

  const MistralProvider({BrowserAiDomAdapter adapter = const BrowserAiDomAdapter()})
      : _adapter = adapter;

  @override
  String get id => 'mistral';

  @override
  String get displayName => 'Mistral Le Chat';

  @override
  Uri get defaultUrl => Uri.parse('https://chat.mistral.ai/chat');

  @override
  bool canHandle(Uri url) => url.host.contains('mistral.ai');

  @override
  Future<bool> isLoggedIn(InAppWebViewController controller) async {
    const js = """
      (function() {
        return !!document.querySelector('textarea') &&
               !document.querySelector('a[href*="login"]') &&
               !document.querySelector('button:has-text("Sign in")');
      })();
    """;
    final res = await controller.evaluateJavascript(source: js);
    return res == true;
  }

  @override
  Future<bool> submitPrompt(InAppWebViewController controller, String prompt) async {
    const inputSelectors = [
      'textarea[placeholder*="Ask"]',
      'textarea[placeholder*="Pregunta"]',
      'textarea[placeholder*="mensaje"]',
      'textarea',
    ];
    const sendSelectors = [
      'button[type="submit"]',
      'button[aria-label*="Send"]',
      'button[aria-label*="Enviar"]',
    ];

    final filled = await _adapter.fillSemanticInput(
      controller,
      selectors: inputSelectors,
      text: prompt,
    );
    if (!filled) return false;

    await Future.delayed(const Duration(milliseconds: 250));
    return await _adapter.clickSend(controller, buttonSelectors: sendSelectors);
  }

  static const _messageSelectors = [
    'div.prose',
    'div.markdown',
    'div[class*="ChatMessage"]',
  ];

  @override
  Future<int> countMessages(InAppWebViewController controller) async {
    return await _adapter.countMessageNodes(
      controller,
      messageSelectors: _messageSelectors,
    );
  }

  @override
  Future<BrowserAiResponse> waitForResponse(
    InAppWebViewController controller,
    Duration timeout, {
    int baselineCount = 0,
    String? requestId,
  }) async {
    const stopSelectors = [
      'button[aria-label*="Stop"]',
      'button[aria-label*="Detener"]',
    ];

    return await _adapter.waitForStabilization(
      controller,
      providerId: id,
      messageSelectors: _messageSelectors,
      stopButtonSelectors: stopSelectors,
      timeout: timeout,
      initialMessageCount: baselineCount,
      requestId: requestId,
    );
  }
}
