import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../domain/browser_navigation_policy.dart';
import 'browser_network_address_guard.dart';
import 'browser_webview_settings_factory.dart';

export 'browser_network_address_guard.dart';

/// QUÉ HACE:
/// Firewall de seguridad de red, evaluación de popups OAuth y fachada de configuración WebView.
///
/// CÓMO FUNCIONA:
/// Evalúa URIs contra `BrowserNetworkAddressGuard` (anti-SSRF, loopback, RFC1918 y puertos locales),
/// restringe esquemas peligrosos (`file`, `content`, `chrome`, `javascript`, `vbscript`, `data`)
/// y delega la creación de `InAppWebViewSettings` a `BrowserWebViewSettingsFactory`.
///
/// POR QUÉ:
/// Protege el runtime local contra accesos indebidos manteniendo el archivo por debajo de 200 líneas.
class BrowserSecurityFirewall {
  static const List<String> _blockedSchemes = [
    'file',
    'content',
    'chrome',
    'javascript',
    'vbscript',
    'data',
  ];
  static const List<String> _externalAppSchemes = [
    'intent',
    'tel',
    'mailto',
    'whatsapp',
    'tg',
  ];

  static FirewallEvaluation _deny(FirewallSecurityCode code, String reason) =>
      FirewallEvaluation(code: code, isAllowed: false, reason: reason);

  static const FirewallEvaluation _ok = FirewallEvaluation(
    code: FirewallSecurityCode.allowed,
    isAllowed: true,
  );

  static bool isLoopbackHost(String host) =>
      BrowserNetworkAddressGuard.isLoopbackHost(host);

  static bool isPrivateNetworkHost(String host) =>
      BrowserNetworkAddressGuard.isPrivateNetworkHost(host);

  static bool isPrivateOrLoopbackHost(String host) =>
      BrowserNetworkAddressGuard.isPrivateOrLoopbackHost(host);

  /// Evalúa una URI clasificando su seguridad de red con códigos semánticos específicos.
  static FirewallEvaluation evaluateUri(Uri uri) {
    final scheme = uri.scheme.toLowerCase();

    if (_blockedSchemes.contains(scheme)) {
      return _deny(
        FirewallSecurityCode.blockedScheme,
        'Esquema local o no permitido bloqueado por seguridad.',
      );
    }

    if (scheme == 'about') {
      if (uri.path == 'blank' || uri.toString() == 'about:blank') return _ok;
      return _deny(
        FirewallSecurityCode.blockedScheme,
        'Recurso about interno no permitido.',
      );
    }

    if (scheme == 'blob') return _ok;

    if (scheme == 'http' || scheme == 'https') {
      return BrowserNetworkAddressGuard.evaluateHttpTarget(uri);
    }

    if (BrowserNavigationPolicy.isExternalAppScheme(scheme)) {
      return _deny(
        FirewallSecurityCode.externalAppRequest,
        'Solicitud hacia aplicación externa.',
      );
    }

    if (BrowserNavigationPolicy.isCustomScheme(scheme)) {
      return _deny(
        FirewallSecurityCode.customScheme,
        'Esquema personalizado de aplicación.',
      );
    }

    return _deny(
      FirewallSecurityCode.unsupportedScheme,
      'Protocolo o esquema no soportado.',
    );
  }

  static FirewallEvaluation evaluateUrl(String url) {
    try {
      return evaluateUri(Uri.parse(url.trim()));
    } catch (_) {
      return _deny(
        FirewallSecurityCode.unsupportedScheme,
        'URL malformada o inválida.',
      );
    }
  }

  /// Evalúa si una URI solicitada vía `window.open` puede abrirse como popup OAuth.
  static FirewallEvaluation evaluatePopupUri(
    Uri? uri, {
    required bool hasUserGesture,
  }) {
    if (uri == null ||
        uri.toString().isEmpty ||
        uri.toString() == 'about:blank' ||
        (uri.scheme == 'about' && uri.path == 'blank')) {
      return hasUserGesture
          ? _ok
          : _deny(
              FirewallSecurityCode.blockedScheme,
              'Ventana emergente en blanco sin gesto de usuario bloqueada.',
            );
    }

    final base = evaluateUri(uri);
    if (!base.isAllowed) return base;
    if (BrowserNavigationPolicy.isOAuthProviderHost(uri.host)) return _ok;
    return _deny(
      FirewallSecurityCode.blockedScheme,
      'Ventana emergente no permitida: solo proveedores OAuth federados.',
    );
  }

  static bool isPopupNavigationAllowed(Uri uri) {
    if (uri.toString() == 'about:blank') return true;
    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'http' && scheme != 'https') return false;
    return evaluateUri(uri).isAllowed;
  }

  static bool isAllowedUrl(String url) => evaluateUrl(url).isAllowed;

  static bool isExternalScheme(String url) {
    try {
      final uri = Uri.parse(url.trim());
      final scheme = uri.scheme.toLowerCase();
      if (_externalAppSchemes.contains(scheme)) return true;
      final target = BrowserNavigationPolicy.classifyUri(uri);
      return target == NavigationTargetType.externalApp ||
          target == NavigationTargetType.phone ||
          target == NavigationTargetType.email ||
          target == NavigationTargetType.store;
    } catch (_) {
      return false;
    }
  }

  static String sanitizeWebContentForLLM({
    required String rawContent,
    required String sourceUrl,
    required String pageTitle,
  }) => BrowserWebViewSettingsFactory.sanitizeWebContentForLLM(
    rawContent: rawContent,
    sourceUrl: sourceUrl,
    pageTitle: pageTitle,
  );

  static InAppWebViewSettings get defaultWebViewSettings =>
      createWebViewSettings();

  static InAppWebViewSettings createWebViewSettings({
    bool isDesktopMode = false,
    bool forceMobileLayout = false,
    String? userAgent,
    bool enableGeolocation = false,
    bool enableOAuthPopups = false,
  }) => BrowserWebViewSettingsFactory.create(
    isDesktopMode: isDesktopMode,
    forceMobileLayout: forceMobileLayout,
    userAgent: userAgent,
    enableGeolocation: enableGeolocation,
    enableOAuthPopups: enableOAuthPopups,
  );
}
