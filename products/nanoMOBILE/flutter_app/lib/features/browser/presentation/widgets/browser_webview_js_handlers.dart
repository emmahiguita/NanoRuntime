// QUÉ: Registro seguro de handlers de JavaScript para el WebView de Nano Browser.
// CÓMO: Valida firmas de origen (HTTPS, no WhatsApp/OAuth) para nanoZoomUpdate y nanoSaveCredential.
// POR QUÉ: Aplica OWASP MASTG e impide inyección fraudulenta manteniendo archivos < 200 líneas.

import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/browser_tab_notifier.dart';
import '../../domain/browser_navigation_policy.dart';

class BrowserWebViewJsHandlers {
  static bool isExcludedCredentialHost(String host) {
    final h = host.trim().toLowerCase();
    if (h.isEmpty) return true;
    if (h == 'web.whatsapp.com' ||
        h == 'whatsapp.com' ||
        h.endsWith('.whatsapp.com')) {
      return true;
    }
    return BrowserNavigationPolicy.isOAuthProviderHost(h);
  }

  static void attachHandlers({
    required InAppWebViewController ctrl,
    required String tabId,
    required WidgetRef ref,
    required bool Function() isAlive,
    required void Function(double scale) onZoomChanged,
    required void Function(String domain, String username, String password)
        onPromptSaveCredential,
  }) {
    ctrl.addJavaScriptHandler(
      handlerName: 'nanoZoomUpdate',
      callback: (args) {
        if (!isAlive() || args.isEmpty || args[0] is! num) return null;
        final value = (args[0] as num).toDouble();
        if (!value.isFinite) return null;
        final z = value.clamp(0.1, 3.0);
        onZoomChanged(z);
        ref
            .read(browserTabProvider.notifier)
            .updateTabById(tabId, zoomLevel: z);
        return null;
      },
    );

    ctrl.addJavaScriptHandler(
      handlerName: 'nanoSaveCredential',
      callback: (args) async {
        if (!isAlive() || args.length < 3) return null;
        final password = args[2]?.toString() ?? '';
        if (password.isEmpty) return null;
        final currentUrl = await ctrl.getUrl();
        if (!isAlive() || currentUrl == null) return null;
        final scheme = currentUrl.scheme.toLowerCase();
        final actualHost = currentUrl.host.trim().toLowerCase();
        final claimedHost =
            (args[0]?.toString() ?? '').trim().toLowerCase();
        if (scheme != 'https' || isExcludedCredentialHost(actualHost)) {
          return null;
        }
        if (claimedHost.isNotEmpty && claimedHost != actualHost) return null;
        onPromptSaveCredential(
          actualHost,
          args[1]?.toString() ?? '',
          password,
        );
        return null;
      },
    );
  }
}
