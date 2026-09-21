import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../../domain/browser_ai_provider.dart';
import '../../domain/browser_ai_response.dart';
import '../browser_ai_dom_adapter.dart';

/// QUÉ HACE:
/// Proveedor de integración con DeepSeek (chat.deepseek.com) vía DOM.
///
/// CÓMO FUNCIONA:
/// Localiza el área de texto de DeepSeek, inyecta la consulta y extrae el
/// contenido renderizado en markdown con soporte para razonamiento profundo (R1).
///
/// POR QUÉ:
/// Ofrece capacidades punteras de programación y razonamiento matemático.
class DeepSeekProvider implements BrowserAiProvider {
  final BrowserAiDomAdapter _adapter;

  const DeepSeekProvider({BrowserAiDomAdapter adapter = const BrowserAiDomAdapter()})
      : _adapter = adapter;

  @override
  String get id => 'deepseek';

  @override
  String get displayName => 'DeepSeek';

  @override
  Uri get defaultUrl => Uri.parse('https://chat.deepseek.com');

  @override
  bool canHandle(Uri url) => url.host.contains('deepseek.com');

  @override
  Future<bool> isLoggedIn(InAppWebViewController controller) async {
    const js = """
      (function() {
        return !!document.querySelector('textarea#chat-input') ||
               !!document.querySelector('textarea[placeholder*="DeepSeek"]') ||
               !!document.querySelector('textarea[placeholder*="pregúntame"]') ||
               !!document.querySelector('textarea') ||
               !!document.querySelector('div[contenteditable="true"]') ||
               !!document.querySelector('div[role="button"][aria-disabled="false"]');
      })();
    """;
    final res = await controller.evaluateJavascript(source: js);
    return res == true;
  }

  @override
  Future<bool> submitPrompt(InAppWebViewController controller, String prompt) async {
    const inputSelectors = [
      'textarea#chat-input',
      'textarea[placeholder*="DeepSeek"]',
      'textarea[placeholder*="pregúntame"]',
      'textarea',
      'div[contenteditable="true"]',
    ];
    const sendSelectors = [
      'div[role="button"][aria-disabled="false"]',
      'button[aria-label*="Send"]',
      'div[class*="send-button"]',
      'div[class*="arrow-up"]',
      'button',
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
    '.ds-markdown',
    'div[class*="chat-message-content"]',
    'div.markdown',
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
      'div[role="button"][aria-label*="Stop"]',
      'div[aria-label*="Detener"]',
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
