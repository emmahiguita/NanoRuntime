// qwen_provider.dart — Integración web para Alibaba Qwen Chat (chat.qwen.ai).
// QUÉ HACE: Conecta Nano AI con el modelo de lenguaje Qwen de Alibaba vía DOM.
// CÓMO FUNCIONA: Detecta sesión iniciada, envía prompts y extrae respuestas estructuradas.
// POR QUÉ: Qwen destaca en programación multilingüe, código fuente y razonamiento.
library;

import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../../domain/browser_ai_provider.dart';
import '../../domain/browser_ai_response.dart';
import '../browser_ai_dom_adapter.dart';

class QwenProvider implements BrowserAiProvider {
  final BrowserAiDomAdapter _adapter;

  const QwenProvider({BrowserAiDomAdapter adapter = const BrowserAiDomAdapter()})
      : _adapter = adapter;

  @override
  String get id => 'qwen';

  @override
  String get displayName => 'Qwen';

  @override
  Uri get defaultUrl => Uri.parse('https://chat.qwen.ai');

  @override
  bool canHandle(Uri url) =>
      url.host.contains('qwen.ai') || url.host.contains('tongyi.aliyun.com');

  @override
  Future<bool> isLoggedIn(InAppWebViewController controller) async {
    const js = """
      (function() {
        return !!document.querySelector('textarea[placeholder*="Qwen"]') ||
               !!document.querySelector('textarea#chat-input') ||
               !!document.querySelector('textarea') ||
               !!document.querySelector('div[contenteditable="true"]') ||
               !!document.querySelector('button[aria-label*="Send"]');
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
      'textarea[placeholder*="Qwen"]',
      'textarea#chat-input',
      'div[contenteditable="true"]',
      'textarea',
    ];
    const sendSelectors = [
      'button[aria-label*="Send"]',
      'button[type="submit"]',
      '.send-btn',
      'button.ant-btn-primary',
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
    '.qwen-markdown',
    '.message-assistant',
    'div[data-role="assistant"]',
    '.markdown-body',
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
      '.stop-generate',
      'button.stop-btn',
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
