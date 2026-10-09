import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../infrastructure/browser_security_firewall.dart';
import 'browser_webview_dialog_guard.dart';
import 'browser_web_identity_coordinator.dart';

/// Aplica la política de navegación y permisos sin mezclarla con la carga.
///
/// Se mantiene separada del ciclo de vida para que una URL externa, un reto
/// TLS o un permiso web tengan una única puerta de seguridad reutilizable.
class BrowserWebViewNavigationGuard {
  BrowserWebViewNavigationGuard({
    required BuildContext Function() context,
    required WidgetRef ref,
    required this.isAlive,
    required this.identity,
    this.onExternalPrompt,
  }) : _dialogs = BrowserWebViewDialogGuard(
         context: context,
         ref: ref,
         isAlive: isAlive,
       );

  final bool Function() isAlive;
  final BrowserWebIdentityCoordinator identity;
  final void Function(String url)? onExternalPrompt;
  final BrowserWebViewDialogGuard _dialogs;

  /// Detiene una carga principal que no cumple la política del firewall.
  bool allowsLoad(InAppWebViewController controller, String url) {
    if (BrowserSecurityFirewall.isAllowedUrl(url)) return true;
    controller.stopLoading();
    _dialogs.showBlocked(
      url: url,
      reason: 'Dirección o protocolo bloqueado por Firewall de Seguridad.',
    );
    return false;
  }

  /// Decide cada navegación antes de entregar privilegios a la página.
  Future<NavigationActionPolicy> shouldOverrideUrlLoading(
    InAppWebViewController controller,
    NavigationAction action,
  ) async {
    if (!isAlive()) return NavigationActionPolicy.CANCEL;
    final uri = action.request.url?.uriValue;
    if (uri == null) return NavigationActionPolicy.CANCEL;
    final url = uri.toString();
    if (BrowserSecurityFirewall.isExternalScheme(url)) {
      onExternalPrompt?.call(url);
      return NavigationActionPolicy.CANCEL;
    }
    if (!BrowserSecurityFirewall.isAllowedUrl(url)) {
      _dialogs.showBlocked(
        url: url,
        reason:
            'Dirección privada, puerto interno o protocolo no seguro bloqueado.',
      );
      return NavigationActionPolicy.CANCEL;
    }
    // Cancela esta petición cuando primero debe cambiar la identidad HTTP;
    // el coordinador vuelve a lanzarla una vez aplicados UA y Client Hints.
    if (await identity.intercept(controller, action.request)) {
      return NavigationActionPolicy.CANCEL;
    }
    return NavigationActionPolicy.ALLOW;
  }

  /// Conserva la decisión TLS en el diálogo de seguridad existente.
  Future<ServerTrustAuthResponse?> requestServerTrust(
    InAppWebViewController controller,
    URLAuthenticationChallenge challenge,
  ) => _dialogs.requestServerTrust(challenge);

  /// Solicita credenciales HTTP sin exponerlas al coordinador de carga.
  Future<HttpAuthResponse?> requestHttpAuth(
    InAppWebViewController controller,
    URLAuthenticationChallenge challenge,
  ) => _dialogs.requestHttpAuth(challenge);

  /// Pide consentimiento para cámara o micrófono desde un único punto.
  Future<PermissionResponse> requestPermission(
    InAppWebViewController controller,
    PermissionRequest request,
  ) => _dialogs.requestPermission(request);
}
