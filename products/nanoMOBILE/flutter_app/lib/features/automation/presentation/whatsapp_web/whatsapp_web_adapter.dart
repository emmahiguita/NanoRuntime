// whatsapp_web_adapter.dart
//
// QUÉ HACE:
// Adaptador de infraestructura visual y navegación para web.whatsapp.com en Nano Mobile.
//
// CÓMO FUNCIONA:
// - Restringe la navegación a dominios legítimos HTTPS de WhatsApp.
// - Carga y almacena en caché las hojas de estilo responsive (mobile.css / tablet.css).
// - Delega la generación de scripts de inyección a WhatsAppWebScripts.
// - Sincroniza bidireccionalmente la máquina de estados de navegación (chatList <-> conversation)
//   entre Flutter y el DOM de WhatsApp Web sin latencia.
//
// POR QUÉ:
// Aplica SOLID (SRP, DIP) desacoplando la lógica de scripts y tipos en módulos dedicados.
// Garantiza un mantenimiento predecible con código testeado bajo 200 líneas.

import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'models/whatsapp_web_types.dart';
import 'scripts/whatsapp_web_scripts.dart';

export 'models/whatsapp_web_types.dart';

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
  static final Map<String, String> _cssCache = <String, String>{};

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
    return allowedHosts.any(
      (allowed) => host == allowed || host.endsWith('.$allowed'),
    );
  }

  /// Inyecta el CSS responsive desde assets según la orientación.
  Future<void> applyResponsiveCss({required bool useTabletLayout}) async {
    final ctrl = _controller;
    if (ctrl == null) return;
    try {
      final path = useTabletLayout
          ? 'assets/browser_adapters/whatsapp/tablet.css'
          : 'assets/browser_adapters/whatsapp/mobile.css';
      final css = _cssCache[path] ??= await rootBundle.loadString(path);
      final encodedCss = jsonEncode(css);
      final variant = useTabletLayout ? 'tablet' : 'mobile';

      final script = WhatsAppWebScripts.buildResponsiveScript(
        encodedCss: encodedCss,
        variant: variant,
      );
      await ctrl.evaluateJavascript(source: script);
      _displayMode = useTabletLayout
          ? WhatsAppDisplayMode.tablet
          : WhatsAppDisplayMode.mobile;
      await syncNavigationState(_navState);
    } catch (_) {
      _displayMode = WhatsAppDisplayMode.originalFallback;
    }
  }

  /// Restaura la vista web de fábrica eliminando los overrides inyectados.
  Future<void> restoreOriginalMode() async {
    final ctrl = _controller;
    if (ctrl == null) return;
    await suspendDomObserver();
    _displayMode = WhatsAppDisplayMode.originalFallback;
    await ctrl.evaluateJavascript(
      source: WhatsAppWebScripts.buildRestoreOriginalScript(),
    );
  }

  /// Sincroniza la clase CSS en el body para alternar entre lista o chat fullscreen.
  Future<void> syncNavigationState(WhatsAppNavState state) async {
    _navState = state;
    final ctrl = _controller;
    if (ctrl == null || _displayMode == WhatsAppDisplayMode.originalFallback) {
      return;
    }

    final isChat = state == WhatsAppNavState.conversation;
    await ctrl.evaluateJavascript(
      source: '''
      document.body.classList.toggle('nano-view-chat', $isChat);
      document.body.classList.toggle('nano-view-list', ${!isChat});
      window.__nanoWaForceList = ${!isChat};
      ''',
    );
  }

  /// Intercepta toques en elementos de chat para activar el modo conversación automáticamente.
  Future<void> setupDomObserver({
    required void Function(WhatsAppNavState) onNavChanged,
  }) async {
    final ctrl = _controller;
    if (ctrl == null) return;

    ctrl.removeJavaScriptHandler(handlerName: 'WhatsAppNavEvent');
    ctrl.addJavaScriptHandler(
      handlerName: 'WhatsAppNavEvent',
      callback: (args) {
        if (args.isEmpty || args.first is! Map) return null;
        final map = Map<String, dynamic>.from(args.first as Map);
        final isChatOpen = map['isChatOpen'] == true;
        final nextState = isChatOpen
            ? WhatsAppNavState.conversation
            : WhatsAppNavState.chatList;
        if (nextState != _navState) {
          _navState = nextState;
          syncNavigationState(nextState);
          onNavChanged(nextState);
        }
        return null;
      },
    );

    await ctrl.evaluateJavascript(
      source: WhatsAppWebScripts.buildObserverScript(),
    );
  }

  /// Detiene solo los observadores de navegación al salir de la ruta para ahorrar batería y CPU.
  Future<void> suspendDomObserver() async {
    final ctrl = _controller;
    if (ctrl == null) return;
    ctrl.removeJavaScriptHandler(handlerName: 'WhatsAppNavEvent');
    await ctrl.evaluateJavascript(
      source: WhatsAppWebScripts.buildSuspendObserverScript(),
    );
  }

  /// Cierra la conversación activa en WhatsApp Web simulando el retroceso nativo.
  Future<bool> handleBackPress() async {
    final ctrl = _controller;
    if (ctrl == null) return false;

    if (_displayMode == WhatsAppDisplayMode.originalFallback) {
      final wasWebChat = await ctrl.evaluateJavascript(
        source: "document.body.classList.contains('nano-web-chat')",
      );
      if (wasWebChat == true) {
        await ctrl.evaluateJavascript(
          source: WhatsAppWebScripts.buildBackPressScript(),
        );
        return true;
      }
      return false;
    }

    if (_navState == WhatsAppNavState.conversation) {
      await ctrl.evaluateJavascript(
        source: WhatsAppWebScripts.buildBackPressScript(),
      );
      await syncNavigationState(WhatsAppNavState.chatList);
      return true; // Consumido: volvió a la lista de chats
    }
    return false; // En lista: permite que Nano maneje el retroceso de pantalla
  }
}
