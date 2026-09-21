import 'dart:async';
import 'dart:convert';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../domain/browser_ai_response.dart';

/// QUÉ HACE:
/// Utilidad de manipulación e inspección DOM para chats web de IA.
///
/// CÓMO FUNCIONA:
/// Inyecta JavaScript tolerante a fallos para localizar campos de entrada
/// semánticos (contenteditable / textareas), simular envío y observar la
/// estabilización del texto en streaming.
///
/// POR QUÉ:
/// Evita depender de coordenadas fijas o selectores CSS frágiles que se rompen
/// con cada actualización de interfaz de los proveedores.
class BrowserAiDomAdapter {
  const BrowserAiDomAdapter();

  /// Intenta rellenar el campo de texto usando selectores semánticos en cascada.
  Future<bool> fillSemanticInput(
    InAppWebViewController controller, {
    required List<String> selectors,
    required String text,
  }) async {
    final escapedText = jsonEncode(text);
    final jsonSelectors = jsonEncode(selectors);
    final js = "(function(){const s=$jsonSelectors;let t=null;for(const sel of s){try{"
        "const el=document.querySelector(sel);if(el&&(el.offsetParent!==null||el.offsetWidth>0)){t=el;break;}"
        "}catch(_){}}if(!t)return false;t.focus();if(t.isContentEditable){t.innerText=$escapedText;}"
        "else{t.value=$escapedText;}t.dispatchEvent(new Event('input',{bubbles:true}));"
        "t.dispatchEvent(new Event('change',{bubbles:true}));return true;})();";
    final res = await controller.evaluateJavascript(source: js);
    return res == true;
  }

  /// Hace clic en el botón de enviar o dispara la tecla Enter.
  Future<bool> clickSend(
    InAppWebViewController controller, {
    required List<String> buttonSelectors,
  }) async {
    final jsonSelectors = jsonEncode(buttonSelectors);
    final js = "(function(){const s=$jsonSelectors;for(const sel of s){try{"
        "const b=document.querySelector(sel);if(b&&!b.disabled&&(b.offsetParent!==null||b.offsetWidth>0)){b.click();return true;}"
        "}catch(_){}}if(document.activeElement){const e=new KeyboardEvent('keydown',{bubbles:true,cancelable:true,key:'Enter',code:'Enter',keyCode:13});"
        "document.activeElement.dispatchEvent(e);return true;}return false;})();";
    final res = await controller.evaluateJavascript(source: js);
    return res == true;
  }

  /// Cuenta los nodos de mensajes existentes en el DOM antes de enviar la consulta.
  Future<int> countMessageNodes(
    InAppWebViewController controller, {
    required List<String> messageSelectors,
  }) async {
    final jsonMsg = jsonEncode(messageSelectors);
    final js = "(function(){const msgs=$jsonMsg;let c=0;for(const m of msgs){try{"
        "const n=document.querySelectorAll(m);if(n.length>c)c=n.length;}catch(_){}}return c;})();";
    try {
      final res = await controller.evaluateJavascript(source: js);
      return (res is num) ? res.toInt() : 0;
    } catch (_) {
      return 0;
    }
  }

  /// Observa el DOM hasta que el texto del asistente deje de cambiar (estabilización de stream).
  Future<BrowserAiResponse> waitForStabilization(
    InAppWebViewController controller, {
    required String providerId,
    required List<String> messageSelectors,
    required List<String> stopButtonSelectors,
    required Duration timeout,
    int initialMessageCount = 0,
    String? requestId,
    List<String> captchaSelectors = const [
      'iframe[src*="cloudflare"]',
      'iframe[src*="recaptcha"]',
      'iframe[src*="turnstile"]'
    ],
  }) async {
    final stopwatch = Stopwatch()..start();
    final jsonMsg = jsonEncode(messageSelectors);
    final jsonStop = jsonEncode(stopButtonSelectors);
    final jsonCaptcha = jsonEncode(captchaSelectors);

    String lastText = '';
    int stableCount = 0;

    while (stopwatch.elapsed < timeout) {
      final js = """
        (function() {
          // 1. Detectar CAPTCHA o bloqueo
          const captchas = $jsonCaptcha;
          for (const c of captchas) {
            if (document.querySelector(c)) return { status: 'captcha' };
          }

          // 2. Detectar si aún está generando (botón Stop activo)
          const stops = $jsonStop;
          let isGenerating = false;
          for (const s of stops) {
            const btn = document.querySelector(s);
            if (btn && (btn.offsetParent !== null || btn.offsetWidth > 0)) {
              isGenerating = true;
              break;
            }
          }

          // 3. Extraer último mensaje garantizando que pertenece al nuevo turno
          const msgs = $jsonMsg;
          let latestText = '';
          let currentMsgCount = 0;
          for (const m of msgs) {
            const nodes = document.querySelectorAll(m);
            if (nodes.length > currentMsgCount) currentMsgCount = nodes.length;
            if (nodes.length > $initialMessageCount) {
              const lastNode = nodes[nodes.length - 1];
              latestText = lastNode.innerText || '';
              if (latestText.trim().length > 0) break;
            }
          }

          return {
            status: 'ok',
            hasNewTurn: currentMsgCount > $initialMessageCount,
            generating: isGenerating,
            text: latestText.trim()
          };
        })();
      """;

      try {
        final res = await controller.evaluateJavascript(source: js);
        if (res is Map) {
          if (res['status'] == 'captcha') {
            return BrowserAiResponse.userActionRequired(
              providerId: providerId,
              reason: 'Verificación de seguridad o CAPTCHA requerida en $providerId.',
              duration: stopwatch.elapsed,
              requestId: requestId,
            );
          }

          final text = (res['text'] ?? '').toString();
          final generating = res['generating'] == true;
          final hasNewTurn = res['hasNewTurn'] == true;

          // Solo evaluar estabilización sobre el nuevo turno (evita respuestas anteriores)
          if (hasNewTurn && text.isNotEmpty && text == lastText && !generating) {
            stableCount++;
            if (stableCount >= 2) {
              return BrowserAiResponse.success(
                providerId: providerId,
                content: text,
                duration: stopwatch.elapsed,
                requestId: requestId,
              );
            }
          } else {
            stableCount = 0;
            if (hasNewTurn) lastText = text;
          }
        }
      } catch (_) {}

      await Future.delayed(const Duration(milliseconds: 650));
    }

    if (lastText.isNotEmpty) {
      return BrowserAiResponse.success(
        providerId: providerId,
        content: lastText,
        duration: stopwatch.elapsed,
        requestId: requestId,
      );
    }

    return BrowserAiResponse.failure(
      providerId: providerId,
      error: 'Tiempo de espera agotado sin respuesta estable de $providerId.',
      status: BrowserAiResponseStatus.timeout,
      duration: stopwatch.elapsed,
      requestId: requestId,
    );
  }
}
