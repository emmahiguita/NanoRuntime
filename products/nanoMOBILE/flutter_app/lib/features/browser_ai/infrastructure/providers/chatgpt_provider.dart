import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../../domain/browser_ai_provider.dart';
import '../../domain/browser_ai_response.dart';
import '../browser_ai_dom_adapter.dart';

/// QUÉ HACE:
/// Proveedor de integración con ChatGPT (chatgpt.com) vía DOM.
///
/// CÓMO FUNCIONA:
/// Emplea selectores semánticos tolerantes a cambios para interactuar con la
/// caja de texto de OpenAI, despachar el mensaje y extraer la respuesta del turno asistente.
///
/// POR QUÉ:
/// Permite consultar GPT-4o / modelos de OpenAI sin requerir API key comercial.
class ChatGptProvider implements BrowserAiProvider {
  final BrowserAiDomAdapter _adapter;

  const ChatGptProvider({BrowserAiDomAdapter adapter = const BrowserAiDomAdapter()})
      : _adapter = adapter;

  @override
  String get id => 'chatgpt';

  @override
  String get displayName => 'ChatGPT';

  @override
  Uri get defaultUrl => Uri.parse('https://chatgpt.com');

  @override
  bool canHandle(Uri url) => url.host.contains('chatgpt.com') || url.host.contains('openai.com');

  @override
  Future<bool> isLoggedIn(InAppWebViewController controller) async {
    const js = """
      (function() {
        try {
          const dismiss = document.querySelectorAll('button[aria-label="Close"], [data-testid="close-button"]');
          dismiss.forEach(b => { try { b.click(); } catch(_) {} });
        } catch(_) {}
        return !!document.querySelector('#prompt-textarea') ||
               !!document.querySelector('div[contenteditable="true"]') ||
               !!document.querySelector('textarea[name="prompt-textarea"]') ||
               !!document.querySelector('textarea[placeholder*="Message"]') ||
               !!document.querySelector('textarea[placeholder*="Mensaje"]') ||
               !!document.querySelector('textarea') ||
               !!document.querySelector('button[data-testid="send-button"]');
      })();
    """;
    final res = await controller.evaluateJavascript(source: js);
    return res == true;
  }

  @override
  Future<bool> submitPrompt(InAppWebViewController controller, String prompt) async {
    const inputSelectors = [
      '#prompt-textarea',
      'div[contenteditable="true"][id="prompt-textarea"]',
      'div[contenteditable="true"]',
      'textarea[name="prompt-textarea"]',
      'textarea[placeholder*="Message"]',
      'textarea[placeholder*="Mensaje"]',
      'textarea',
    ];
    const sendSelectors = [
      'button[data-testid="send-button"]',
      'button[aria-label="Send prompt"]',
      'button[aria-label="Enviar prompt"]',
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
    'div[data-message-author-role="assistant"]',
    '.agent-turn .markdown',
    'div.markdown.prose',
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
      'button[data-testid="stop-button"]',
      'button[aria-label="Stop streaming"]',
      'button[aria-label="Detener generación"]',
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
