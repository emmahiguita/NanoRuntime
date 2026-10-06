// copilot_provider.dart — Integración web para Microsoft Copilot (copilot.microsoft.com).
// QUÉ HACE: Conecta Nano AI con Microsoft Copilot vía interfaz DOM web.
// CÓMO FUNCIONA: Localiza el área de texto de Copilot, inyecta prompts y monitoriza streaming.
// POR QUÉ: Permite consultas con la infraestructura GPT-4 de Microsoft sin coste de API.
library;

import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../../domain/browser_ai_provider.dart';
import '../../domain/browser_ai_response.dart';
import '../browser_ai_dom_adapter.dart';

class CopilotProvider implements BrowserAiProvider {
  final BrowserAiDomAdapter _adapter;

  const CopilotProvider({BrowserAiDomAdapter adapter = const BrowserAiDomAdapter()})
      : _adapter = adapter;

  @override
  String get id => 'copilot';

  @override
  String get displayName => 'Copilot';

  @override
  Uri get defaultUrl => Uri.parse('https://copilot.microsoft.com');

  @override
  bool canHandle(Uri url) =>
      url.host.contains('copilot.microsoft.com') ||
      url.host.contains('bing.com');

  @override
  Future<bool> isLoggedIn(InAppWebViewController controller) async {
    const js = """
      (function() {
        return !!document.querySelector('textarea#searchbox') ||
               !!document.querySelector('textarea[placeholder*="Pregúntame"]') ||
               !!document.querySelector('textarea[placeholder*="Ask"]') ||
               !!document.querySelector('textarea') ||
               !!document.querySelector('div[contenteditable="true"]');
      })();
    """;
    final res = await controller.evaluateJavascript(source: js);
    return res == true;
  }

  @override
  Future<bool> submitPrompt(
    InAppWebViewController controller,
    String prompt,
  ) async {
    const inputSelectors = [
      'textarea#searchbox',
      'textarea[placeholder*="Ask"]',
      'textarea[placeholder*="Pregúntame"]',
      'div[contenteditable="true"]',
      'textarea',
    ];
    const sendSelectors = [
      'button[aria-label*="Submit"]',
      'button[aria-label*="Enviar"]',
      'button[type="submit"]',
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
    '.cib-message-main',
    'div[data-content="ai-message"]',
    '.markdown-body',
    'div.prose',
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
