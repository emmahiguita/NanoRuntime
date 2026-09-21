import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:nanoai/features/browser/application/browser_pip_notifier.dart';
import 'package:nanoai/features/browser/domain/browser_pip_model.dart';
import 'package:nanoai/features/browser/infrastructure/browser_scripts.dart';
import 'package:nanoai/features/browser/infrastructure/browser_security_firewall.dart';

/// Superficie WebView dedicada al reproductor Picture-in-Picture.
/// 
/// - ¿Qué hace?: Renderiza el contenido web o de video en una instancia InAppWebView
///   protegida por el firewall SSRF, sincronizando el tiempo de reproducción.
/// - ¿Cómo funciona?: Se conecta al BrowserPipNotifier al crearse y evalúa el
///   viewport móvil y la sincronización de medios en onLoadStop.
/// - ¿Por qué?: Aplica SRP aislando el motor de renderizado web de la interfaz y
///   gestos de arrastre del overlay flotante.
class BrowserPipWebView extends StatelessWidget {
  final BrowserPipState pip;
  final BrowserPipNotifier notifier;

  const BrowserPipWebView({super.key, required this.pip, required this.notifier});

  @override
  Widget build(BuildContext context) {
    final url = pip.url;
    if (url == null || url.isEmpty) {
      return const ColoredBox(
        color: Colors.black,
        child: Center(
          child: Text('Sin contenido multimedia', style: TextStyle(color: Colors.white70, fontSize: 12)),
        ),
      );
    }

    return InAppWebView(
      key: const ValueKey('pip_webview_'),
      initialUrlRequest: URLRequest(url: WebUri(url)),
      initialSettings: BrowserSecurityFirewall.defaultWebViewSettings,
      onWebViewCreated: notifier.attachPipController,
      onLoadStop: (controller, _) async {
        try {
          await controller.evaluateJavascript(source: BrowserScripts.mobileViewportAdapterScript);
          if (url.contains('youtube.com') || url.contains('youtu.be')) {
            await controller.evaluateJavascript(
              source: "document.addEventListener('visibilitychange', function(e) { e.stopImmediatePropagation(); }, true);",
            );
          }
        } catch (_) {}
        await notifier.synchronizePipPlayback();
      },
      shouldOverrideUrlLoading: (controller, action) async {
        final target = action.request.url?.toString();
        if (target == null || !BrowserSecurityFirewall.isAllowedUrl(target)) {
          return NavigationActionPolicy.CANCEL;
        }
        return NavigationActionPolicy.ALLOW;
      },
      onPermissionRequest: (controller, request) async => PermissionResponse(
        resources: request.resources,
        action: PermissionResponseAction.DENY,
      ),
    );
  }
}
