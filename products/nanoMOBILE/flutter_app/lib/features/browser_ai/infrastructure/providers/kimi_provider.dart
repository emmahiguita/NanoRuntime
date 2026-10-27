// kimi_provider.dart — Integración web para Moonshot Kimi (kimi.moonshot.cn / kimi.com).
// QUÉ HACE: Conecta Nano AI con el asistente web Kimi mediante interacción DOM.
// CÓMO FUNCIONA: Detecta sesión activa, inyecta texto en el editor semántico y espera respuesta.
// POR QUÉ: Kimi ofrece excelentes capacidades de análisis de documentos largos y búsqueda web.
library;

import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../../domain/browser_ai_provider.dart';
import '../../domain/browser_ai_response.dart';
import '../browser_ai_dom_adapter.dart';

class KimiProvider implements BrowserAiProvider {
  final BrowserAiDomAdapter _adapter;

  const KimiProvider({BrowserAiDomAdapter adapter = const BrowserAiDomAdapter()})
      : _adapter = adapter;

  @override
  String get id => 'kimi';

  @override
  String get displayName => 'Kimi';

  @override
  Uri get defaultUrl => Uri.parse('https://kimi.moonshot.cn');

  @override
  bool canHandle(Uri url) =>
      url.host.contains('kimi.moonshot.cn') ||
      url.host.contains('kimi.com') ||
      url.host.contains('moonshot.cn');

  @override
  Future<bool> isLoggedIn(InAppWebViewController controller) async {
    const js = """
      (function() {
        return !!document.querySelector('div[contenteditable="true"]') ||
               !!document.querySelector('textarea[placeholder*="Kimi"]') ||
               !!document.querySelector('textarea') ||
               !!document.querySelector('[data-testid="send-btn"]') ||
               !!document.querySelector('.chat-input-editor');
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
      'div[contenteditable="true"].chat-input-editor',
      'div[contenteditable="true"]',
      'textarea[placeholder*="Kimi"]',
      'textarea',
    ];
    const sendSelectors = [
      '[data-testid="send-btn"]',
      'button[aria-label*="Send"]',
      'button[class*="send"]',
      '.send-button',
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
    '.chat-message-item-assistant',
    '.segment-content',
    'div[data-role="assistant"]',
    '.markdown',
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
      'button[class*="stop"]',
      '.stop-generate-button',
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
