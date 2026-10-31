// QUÉ: Gestión de ventanas emergentes (popups) OAuth para la instancia de WebView.
// CÓMO: Evalúa URLs con BrowserSecurityFirewall y controla el ciclo de vida de la capa de login.
// POR QUÉ: Extraído de SingleBrowserInstanceWidget para modularizar responsabilidades (< 80 líneas).

part of 'single_browser_instance_widget.dart';

/// Popup OAuth activo para esta instancia de pestaña. Solo uno a la vez.
class _PendingPopup {
  const _PendingPopup({required this.action});

  final CreateWindowAction action;
}

extension _BrowserInstancePopups on _SingleBrowserInstanceWidgetState {
  /// Decide si un `window.open` del WebView puede materializarse como popup.
  ///
  /// Solo proveedores OAuth federados (y popups en blanco con gesto, que usa
  /// Google Identity Services) pasan el firewall; todo lo demás se niega.
  /// Para conservar el comportamiento legado de `target=_blank` en enlaces
  /// normales, esos destinos se recargan en el marco principal.
  Future<bool?> _handleCreateWindow(
    InAppWebViewController controller,
    CreateWindowAction action,
  ) async {
    final uri = action.request.url?.uriValue;
    final evaluation = BrowserSecurityFirewall.evaluatePopupUri(
      uri,
      hasUserGesture: action.hasGesture ?? false,
    );

    debugPrint(
      '[NanoBrowser] popup=${evaluation.isAllowed ? 'ALLOWED' : 'DENIED'} '
      'url=${uri?.origin ?? 'null'} reason=${evaluation.reason ?? evaluation.code.code}',
    );

    if (!evaluation.isAllowed) {
      if (uri != null &&
          BrowserSecurityFirewall.evaluateUri(uri).isAllowed &&
          BrowserNavigationPolicy.classifyUri(uri) ==
              NavigationTargetType.web) {
        controller.loadUrl(urlRequest: action.request);
      }
      return false;
    }

    if (!mounted || _pendingPopup != null) return false;

    setState(() {
      _pendingPopup = _PendingPopup(action: action);
    });
    return true;
  }

  /// El popup terminó (`window.close()` o cierre manual del usuario).
  ///
  /// [completedByPage] indica que la página cerró el popup tras completar el
  /// login; entonces se recarga el marco principal para que aplique la sesión.
  void _onPopupClosed({bool completedByPage = false}) {
    debugPrint(
      '[NanoBrowser] popup layer retirada (completado=$completedByPage).',
    );
    final controller = _registry.controllerFor(widget.tab.id);
    if (completedByPage && controller != null) {
      controller.reload();
    }
    if (!mounted) return;
    setState(() => _pendingPopup = null);
  }
}
