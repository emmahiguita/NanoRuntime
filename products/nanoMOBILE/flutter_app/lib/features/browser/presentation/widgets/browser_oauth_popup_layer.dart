import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../../domain/browser_navigation_policy.dart';
import '../../domain/tiktok_web_policy.dart';
import '../../infrastructure/browser_security_firewall.dart';

/// Capa emergente que aloja el popup nativo del flujo OAuth federado.
///
/// Solo se instancia después de que [BrowserSecurityFirewall.evaluatePopupUri]
/// autoriza la URL. El WebView queda vinculado al padre por [windowId], de modo
/// que Google Identity Services puede devolver la credencial vía `postMessage`
/// y cerrarse con `window.close()`.
class BrowserOAuthPopupLayer extends StatefulWidget {
  const BrowserOAuthPopupLayer({
    super.key,
    required this.windowId,
    required this.initialRequest,
    required this.onPopupClosed,
    required this.onPopupCompleted,
  });

  final int windowId;
  final URLRequest initialRequest;

  /// Cierre manual del usuario (botón X): no hubo login.
  final VoidCallback onPopupClosed;

  /// La página terminó el flujo con `window.close()`: login completado.
  final VoidCallback onPopupCompleted;

  @override
  State<BrowserOAuthPopupLayer> createState() => _BrowserOAuthPopupLayerState();
}

class _BrowserOAuthPopupLayerState extends State<BrowserOAuthPopupLayer> {
  bool _loading = true;

  /// True tras la primera navegación permitida; evita cerrar el popup cuando
  /// una página legítima (ej. GIS) mezcla navegaciones permitidas y canceladas.
  bool _sawAllowedNavigation = false;

  /// Cierra el popup si el login se abandona abierto; evita ventanas
  /// huérfanas acumuladas en sesiones largas.
  Timer? _abandonTimeout;

  /// GIS abre el popup en blanco (`window.open('')`) y escribe el formulario
  /// dentro; sin documento inicial el WebView no recibiría el contenido.
  URLRequest get _initialRequest =>
      widget.initialRequest.url != null
          ? widget.initialRequest
          : URLRequest(url: WebUri('about:blank'));

  @override
  void initState() {
    super.initState();
    _abandonTimeout = Timer(const Duration(minutes: 3), () {
      debugPrint('[NanoBrowser] popup: timeout de 3 min, se cierra.');
      if (mounted) widget.onPopupClosed();
    });
  }

  @override
  void dispose() {
    _abandonTimeout?.cancel();
    super.dispose();
  }

  /// El popup permite navegación web pública libre (redes privadas, puertos
  /// internos y esquemas de app siguen bloqueados). Se cierra solo cuando:
  /// 1) la PRIMERA navegación ya es inválida (popup inútil), o
  /// 2) intenta un deep link de app ("Abrir en TikTok"): el usuario permanece
  ///    en TikTok Web sin ventanas colgadas.
  Future<NavigationActionPolicy> _guardNavigation(
    InAppWebViewController controller,
    NavigationAction action,
  ) async {
    final uri = action.request.url?.uriValue;
    if (uri == null) return NavigationActionPolicy.CANCEL;

    final isAppLink =
        TikTokWebPolicy.isTikTokAppScheme(uri) ||
        TikTokWebPolicy.isTikTokIntent(uri) ||
        BrowserNavigationPolicy.classifyUri(uri) ==
            NavigationTargetType.externalApp;

    final allowed = BrowserSecurityFirewall.isPopupNavigationAllowed(uri);
    debugPrint(
      '[NanoBrowser] popup navigation=${allowed ? 'ALLOWED' : 'CANCELED'} '
      'url=${uri.toString()}',
    );

    if (!allowed && (isAppLink || !_sawAllowedNavigation)) {
      // Popup inútil o salto a app externa: cerrar en el siguiente frame
      // para no mutar el árbol durante la navegación.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onPopupClosed();
      });
      return NavigationActionPolicy.CANCEL;
    }
    if (allowed) _sawAllowedNavigation = true;
    return allowed
        ? NavigationActionPolicy.ALLOW
        : NavigationActionPolicy.CANCEL;
  }

  /// QUÉ HACE: compone la ventana emergente con alturas 100% adaptativas.
  /// CÓMO: el WebView se expande dentro del espacio real disponible de la
  /// tarjeta contenedora (Expanded), sin alturas fijas basadas en pantalla.
  /// POR QUÉ: una altura fija (ej. 82% de pantalla) desborda la tarjeta
  /// cuando el navegador no está maximizado y pinta la franja amarilla de
  /// overflow de Flutter.
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.black54,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      color: scheme.surface,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.lock_outline,
                            size: 18,
                            color: scheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Inicio de sesión seguro',
                              style:
                                  Theme.of(context).textTheme.titleSmall,
                            ),
                          ),
                          IconButton(
                            tooltip: 'Cerrar',
                            icon: const Icon(Icons.close),
                            onPressed: widget.onPopupClosed,
                          ),
                        ],
                      ),
                    ),
                    if (_loading)
                      const LinearProgressIndicator(minHeight: 2),
                    Expanded(
                      child: InAppWebView(
                        windowId: widget.windowId,
                        initialUrlRequest: _initialRequest,
                        initialSettings:
                            BrowserSecurityFirewall.createWebViewSettings(),
                        onLoadStart: (_, __) {
                          if (!_loading && mounted) {
                            setState(() => _loading = true);
                          }
                        },
                        onLoadStop: (_, __) {
                          if (mounted) setState(() => _loading = false);
                        },
                        shouldOverrideUrlLoading: _guardNavigation,
                        onReceivedError: (_, request, error) {
                          debugPrint(
                            '[NanoBrowser] popup error=${error.description} '
                            'url=${request.url}',
                          );
                        },
                        // GIS cierra el popup con window.close() al terminar.
                        onCloseWindow: (_) {
                          debugPrint('[NanoBrowser] popup closed por la página.');
                          widget.onPopupCompleted();
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
