import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../../domain/browser_ai_provider.dart';
import '../../domain/browser_ai_response.dart';
import '../browser_ai_dom_adapter.dart';

/// QUÉ HACE:
/// Proveedor de integración con Anthropic Claude (claude.ai) vía DOM.
///
/// CÓMO FUNCIONA:
/// Localiza el editor ProseMirror de Claude, despacha el contenido y extrae
/// el bloque de respuesta formateado con soporte para razonamiento profundo.
///
/// POR QUÉ:
/// Permite usar Claude 3.5 Sonnet sin costos de token de API.
class ClaudeProvider implements BrowserAiProvider {
  final BrowserAiDomAdapter _adapter;

  const ClaudeProvider({BrowserAiDomAdapter adapter = const BrowserAiDomAdapter()})
      : _adapter = adapter;

  @override
  String get id => 'claude';

  @override
  String get displayName => 'Anthropic Claude';

  @override
  Uri get defaultUrl => Uri.parse('https://claude.ai/new');

  @override
  bool canHandle(Uri url) => url.host.contains('claude.ai');

  @override
  Future<bool> isLoggedIn(InAppWebViewController controller) async {
    const js = """
      (function() {
        return !!document.querySelector('div.ProseMirror') ||
               !!document.querySelector('[aria-label*="Claude"]');
      })();
    """;
    final res = await controller.evaluateJavascript(source: js);
    return res == true;
  }

  @override
  Future<bool> submitPrompt(InAppWebViewController controller, String prompt) async {
    const inputSelectors = [
      'div[contenteditable="true"].ProseMirror',
      'div.ProseMirror',
      'div[contenteditable="true"]',
      '[aria-label*="prompt to Claude"]',
    ];
    const sendSelectors = [
      'button[aria-label*="Send Message"]',
      'button[aria-label*="Enviar mensaje"]',
      'button[aria-label*="Send"]',
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
    'div.font-claude-message',
    '.standard-markdown',
    'div[data-is-streaming]',
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
      'button[aria-label*="Stop response"]',
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
