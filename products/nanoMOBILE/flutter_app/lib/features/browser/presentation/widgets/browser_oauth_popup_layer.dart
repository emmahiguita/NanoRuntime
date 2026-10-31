// QUÉ: Capa emergente que aloja el popup nativo del flujo OAuth federado.
// CÓMO: Abre ventana segura vinculada al windowId con timeout y guardia de navegación.
// POR QUÉ: Permite autenticación con Google/OAuth sin romper la sesión del marco principal (< 170 líneas).

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../../domain/browser_navigation_policy.dart';
import '../../domain/tiktok_web_policy.dart';
import '../../infrastructure/browser_security_firewall.dart';

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
  final VoidCallback onPopupClosed;
  final VoidCallback onPopupCompleted;

  @override
  State<BrowserOAuthPopupLayer> createState() => _BrowserOAuthPopupLayerState();
}

class _BrowserOAuthPopupLayerState extends State<BrowserOAuthPopupLayer> {
  bool _loading = true;
  bool _sawAllowedNavigation = false;
  Timer? _abandonTimeout;

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
                              style: Theme.of(context).textTheme.titleSmall,
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
                    if (_loading) const LinearProgressIndicator(minHeight: 2),
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
                        onCloseWindow: (_) {
                          debugPrint(
                            '[NanoBrowser] popup closed por la página.',
                          );
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
