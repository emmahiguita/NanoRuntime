// custom_dynamic_provider.dart — Proveedor configurable dinámicamente por el usuario.
// QUÉ HACE: Permite al usuario añadir cualquier chat web de IA nuevo (Mistral, Grok, etc.).
// CÓMO FUNCIONA: Usa selectores semánticos universales (contenteditable, textarea, button[type=submit]).
// POR QUÉ: Evita tener que recompilar la aplicación cada vez que se lance un nuevo servicio web de IA.
library;

import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../../domain/browser_ai_provider.dart';
import '../../domain/browser_ai_response.dart';
import '../browser_ai_dom_adapter.dart';

class CustomDynamicProvider implements BrowserAiProvider {
  final String customId;
  final String name;
  final Uri url;
  final BrowserAiDomAdapter _adapter;

  const CustomDynamicProvider({
    required this.customId,
    required this.name,
    required this.url,
    BrowserAiDomAdapter adapter = const BrowserAiDomAdapter(),
  }) : _adapter = adapter;

  @override
  String get id => customId;

  @override
  String get displayName => name;

  @override
  Uri get defaultUrl => url;

  @override
  bool canHandle(Uri targetUrl) => targetUrl.host.contains(url.host);

  @override
  Future<bool> isLoggedIn(InAppWebViewController controller) async {
    const js = """
      (function() {
        return !!document.querySelector('textarea') ||
               !!document.querySelector('div[contenteditable="true"]') ||
               !!document.querySelector('input[type="text"]') ||
               !!document.querySelector('button[type="submit"]');
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
      'div[contenteditable="true"]',
      'textarea[placeholder*="Message"]',
      'textarea[placeholder*="Mensaje"]',
      'textarea[placeholder*="Ask"]',
      'textarea[placeholder*="Pregunta"]',
      'textarea',
      'input[type="text"]',
    ];
    const sendSelectors = [
      'button[type="submit"]',
      'button[aria-label*="Send"]',
      'button[aria-label*="Enviar"]',
      'button[aria-label*="Submit"]',
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
    'div[data-message-author-role="assistant"]',
    'div.prose',
    'div.markdown',
    '.agent-turn',
    '.assistant-message',
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
