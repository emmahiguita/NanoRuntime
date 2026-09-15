import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../infrastructure/browser_security_firewall.dart';

class BrowserContextExtractor {
  /// Extrae el texto actualmente seleccionado por el usuario en la página web.
  static Future<String?> extractSelection(InAppWebViewController controller) async {
    try {
      final jsResult = await controller.evaluateJavascript(
        source: 'window.getSelection().toString();',
      );
      if (jsResult != null && jsResult.toString().trim().isNotEmpty) {
        return jsResult.toString().trim();
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Extrae el texto legible completo del cuerpo de la página web activa.
  static Future<String?> extractFullPageText(InAppWebViewController controller) async {
    try {
      final jsResult = await controller.evaluateJavascript(
        source: '''
          (function() {
            var body = document.body;
            if (!body) return "";
            var clone = body.cloneNode(true);
            var scripts = clone.getElementsByTagName("script");
            var styles = clone.getElementsByTagName("style");
            var noscripts = clone.getElementsByTagName("noscript");
            while (scripts[0]) scripts[0].parentNode.removeChild(scripts[0]);
            while (styles[0]) styles[0].parentNode.removeChild(styles[0]);
            while (noscripts[0]) noscripts[0].parentNode.removeChild(noscripts[0]);
            return clone.innerText || clone.textContent || "";
          })();
        ''',
      );
      if (jsResult != null && jsResult.toString().trim().isNotEmpty) {
        return jsResult.toString().trim();
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Extrae el contexto web sanitizado para ser transferido directamente al módulo de Chat.
  static Future<String?> getSanitizedContext({
    required InAppWebViewController controller,
    required String sourceUrl,
    required String pageTitle,
  }) async {
    // Intentar primero texto seleccionado
    final selection = await extractSelection(controller);
    final rawText = selection ?? await extractFullPageText(controller);

    if (rawText == null || rawText.isEmpty) {
      return null;
    }

    // Limitar longitud para no saturar el context window (ej. 8000 caracteres max)
    final truncated = rawText.length > 8000
        ? '${rawText.substring(0, 8000)}\n... [Texto truncado por límite de longitud]'
        : rawText;

    return BrowserSecurityFirewall.sanitizeWebContentForLLM(
      rawContent: truncated,
      sourceUrl: sourceUrl,
      pageTitle: pageTitle,
    );
  }
}
