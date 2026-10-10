// whatsapp_web_adapter.dart
//
// QUÉ HACE:
// Adaptador de infraestructura visual y navegación para web.whatsapp.com dentro de Nano.
//
// CÓMO FUNCIONA:
// - Valida hosts permitidos restringidos (solo WhatsApp HTTPS legítimo).
// - Carga e inyecta CSS responsive desde assets (mobile.css / tablet.css) sin strings estáticos en Dart.
// - Conmuta dinámicamente clases en el DOM (nano-view-list <-> nano-view-chat) para navegación fullscreen.
// - Provee fallback seguro a la vista web original si Meta altera el DOM.
//
// POR QUÉ:
// Cumple SRP, SOLID y mantiene el adaptador bajo 180 líneas sin lógica acoplada a la shell.

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

enum WhatsAppDisplayMode { mobile, tablet, originalFallback }

enum WhatsAppNavState { chatList, conversation }

class WhatsAppWebAdapter {
  static const String entryUrl = 'https://web.whatsapp.com';
  static const List<String> allowedHosts = [
    'web.whatsapp.com',
    'whatsapp.com',
    'www.whatsapp.com',
  ];

  InAppWebViewController? _controller;
  WhatsAppDisplayMode _displayMode = WhatsAppDisplayMode.mobile;
  WhatsAppNavState _navState = WhatsAppNavState.chatList;

  WhatsAppDisplayMode get displayMode => _displayMode;
  WhatsAppNavState get navState => _navState;
  bool get isConversationActive => _navState == WhatsAppNavState.conversation;

  void attachController(InAppWebViewController controller) {
    _controller = controller;
  }

  void detachController() {
    _controller = null;
  }

  /// Valida rigurosamente que el scheme sea https y el host pertenezca a WhatsApp.
  static bool isAllowedUrl(String url) {
    final uri = Uri.tryParse(url.trim());
    if (uri == null || uri.scheme.toLowerCase() != 'https') return false;
    final host = uri.host.toLowerCase();
    return allowedHosts.any((allowed) => host == allowed || host.endsWith('.$allowed'));
  }

  /// Inyecta el CSS responsive desde assets según la orientación.
  Future<void> applyResponsiveCss({required bool isLandscape}) async {
    final ctrl = _controller;
    if (ctrl == null) return;
    if (_displayMode == WhatsAppDisplayMode.originalFallback) return;

    try {
      final path = isLandscape
          ? 'assets/browser_adapters/whatsapp/tablet.css'
          : 'assets/browser_adapters/whatsapp/mobile.css';
      final css = await rootBundle.loadString(path);
      await ctrl.injectCSSCode(source: css);
      _displayMode = isLandscape ? WhatsAppDisplayMode.tablet : WhatsAppDisplayMode.mobile;
      await syncNavigationState(_navState);
    } catch (_) {
      // Fallback silencioso sin crash: el sitio se mantendrá en modo original si falla el CSS.
      _displayMode = WhatsAppDisplayMode.originalFallback;
    }
  }

  /// Restaura la vista web de fábrica eliminando la clase o inyectando override neutral.
  Future<void> restoreOriginalMode() async {
    final ctrl = _controller;
    if (ctrl == null) return;
    _displayMode = WhatsAppDisplayMode.originalFallback;
    await ctrl.evaluateJavascript(source: '''
      document.body.classList.remove('nano-view-list', 'nano-view-chat');
      var s = document.getElementById('nano-wa-responsive-style');
      if (s) s.remove();
    ''');
  }

  /// Sincroniza la clase CSS en el body para alternar entre lista o chat fullscreen.
  Future<void> syncNavigationState(WhatsAppNavState state) async {
    _navState = state;
    final ctrl = _controller;
    if (ctrl == null || _displayMode == WhatsAppDisplayMode.originalFallback) return;

    final className = state == WhatsAppNavState.conversation ? 'nano-view-chat' : 'nano-view-list';
    final removeClass = state == WhatsAppNavState.conversation ? 'nano-view-list' : 'nano-view-chat';

    await ctrl.evaluateJavascript(source: '''
      document.body.classList.remove('$removeClass');
      document.body.classList.add('$className');
    ''');
  }

  /// Intercepta toques en elementos de chat para activar el modo conversación automáticamente.
  Future<void> setupDomObserver({required void Function(WhatsAppNavState) onNavChanged}) async {
    final ctrl = _controller;
    if (ctrl == null) return;

    // Script ligero que detecta si el panel #main tiene un chat activo
    await ctrl.evaluateJavascript(source: '''
      (function() {
        if (window.__nanoWaObserver) return;
        window.__nanoWaObserver = true;

        var checkActiveChat = function() {
          var main = document.getElementById('main');
          var isChatOpen = main && main.querySelector('header') !== null;
          if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
            window.flutter_inappwebview.callHandler('WhatsAppNavEvent', {
              isChatOpen: isChatOpen
            });
          }
        };

        var observer = new MutationObserver(function() {
          checkActiveChat();
        });

        var app = document.getElementById('app');
        if (app) {
          observer.observe(app, { childList: true, subtree: true });
        }
      })();
    ''');

    ctrl.removeJavaScriptHandler(handlerName: 'WhatsAppNavEvent');
    ctrl.addJavaScriptHandler(
      handlerName: 'WhatsAppNavEvent',
      callback: (args) {
        if (args.isEmpty || args.first is! Map) return null;
        final map = Map<String, dynamic>.from(args.first as Map);
        final isChatOpen = map['isChatOpen'] == true;
        final nextState = isChatOpen ? WhatsAppNavState.conversation : WhatsAppNavState.chatList;
        if (nextState != _navState) {
          _navState = nextState;
          syncNavigationState(nextState);
          onNavChanged(nextState);
        }
        return null;
      },
    );
  }

  /// Cierra la conversación activa en WhatsApp Web simulando el escape / botón atrás web.
  Future<bool> handleBackPress() async {
    final ctrl = _controller;
    if (ctrl == null) return false;

    if (_navState == WhatsAppNavState.conversation) {
      await ctrl.evaluateJavascript(source: '''
        var backBtn = document.querySelector('#main header span[data-icon="back"]') ||
                      document.querySelector('#main header button[aria-label="Back"]');
        if (backBtn) {
          backBtn.click();
        } else {
          window.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape', code: 'Escape', keyCode: 27 }));
        }
      ''');
      await syncNavigationState(WhatsAppNavState.chatList);
      return true; // Consumido: volvió a la lista
    }
    return false; // En lista: permite que Nano maneje el retroceso
  }
}
