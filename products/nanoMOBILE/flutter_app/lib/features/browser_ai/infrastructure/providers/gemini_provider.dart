import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../../domain/browser_ai_provider.dart';
import '../../domain/browser_ai_response.dart';
import '../browser_ai_dom_adapter.dart';

/// QUÉ HACE:
/// Proveedor de integración con Google Gemini (gemini.google.com) vía DOM.
///
/// CÓMO FUNCIONA:
/// Emplea selectores semánticos para el editor rich-text de Gemini, dispara el
/// botón de envío y extrae la respuesta del contenedor de modelo.
///
/// POR QUÉ:
/// Permite utilizar los modelos de razonamiento y ventana de contexto larga de Google.
class GeminiProvider implements BrowserAiProvider {
  final BrowserAiDomAdapter _adapter;

  const GeminiProvider({BrowserAiDomAdapter adapter = const BrowserAiDomAdapter()})
      : _adapter = adapter;

  @override
  String get id => 'gemini';

  @override
  String get displayName => 'Google Gemini';

  @override
  Uri get defaultUrl => Uri.parse('https://gemini.google.com/app');

  @override
  bool canHandle(Uri url) => url.host.contains('gemini.google.com');

  @override
  Future<bool> isLoggedIn(InAppWebViewController controller) async {
    const js = """
      (function() {
        return !!document.querySelector('div.ql-editor') ||
               !!document.querySelector('rich-textarea') ||
               !!document.querySelector('[aria-label*="prompt"]');
      })();
    """;
    final res = await controller.evaluateJavascript(source: js);
    return res == true;
  }

  @override
  Future<bool> submitPrompt(InAppWebViewController controller, String prompt) async {
    const inputSelectors = [
      'div.ql-editor[contenteditable="true"]',
      'rich-textarea div[contenteditable="true"]',
      'div[contenteditable="true"]',
      '[aria-label*="Enter a prompt"]',
      '[aria-label*="Introduce una instrucción"]',
    ];
    const sendSelectors = [
      'button.send-button',
      'button[aria-label*="Send message"]',
      'button[aria-label*="Enviar"]',
      'button.mat-mdc-tooltip-trigger[aria-label*="Send"]',
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
    'message-content.model-response-text',
    '.response-container-content',
    'model-response .markdown',
    '.model-response-text',
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
      'button[aria-label*="Cancel"]',
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
