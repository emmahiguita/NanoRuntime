// QUÉ: Manejadores de esquemas de navegación (web interna, intents, esquemas no soportados).
// CÓMO: Implementa las ramas de decisión específicas de NavigationTargetType para el guard.
// POR QUÉ: Extraído de BrowserWebViewNavigationGuard para mantener el límite estricto de 200 líneas.

part of 'browser_webview_navigation_guard.dart';

extension _BrowserNavigationGuardHandlers on BrowserWebViewNavigationGuard {
  NavigationActionPolicy _handleInternalWeb(
    Uri uri,
    String scheme,
    String origin,
    NavigationTargetType targetType,
    bool userGesture,
  ) {
    if (scheme == 'about') {
      if (uri.path == 'blank' || uri.toString() == 'about:blank') {
        _dispatcher.logNavigation(
          navigation: 'INTERNAL_WEB_ALLOWED',
          scheme: scheme,
          origin: origin,
          targetType: targetType,
          userGesture: userGesture,
          decision: 'ALLOW',
        );
        return NavigationActionPolicy.ALLOW;
      }
      _dispatcher.logNavigation(
        navigation: FirewallSecurityCode.blockedScheme.code,
        scheme: scheme,
        origin: origin,
        targetType: targetType,
        userGesture: userGesture,
        decision: 'BLOCKED',
      );
      _dialogs.showBlocked(
        url: uri.toString(),
        reason: 'Recurso about interno no permitido.',
      );
      return NavigationActionPolicy.CANCEL;
    }
    _dispatcher.logNavigation(
      navigation: 'INTERNAL_WEB_ALLOWED',
      scheme: scheme,
      origin: origin,
      targetType: targetType,
      userGesture: userGesture,
      decision: 'ALLOW',
    );
    return NavigationActionPolicy.ALLOW;
  }

  NavigationActionPolicy _handleIntentScheme(
    Uri uri,
    String scheme,
    String origin,
    NavigationTargetType targetType,
    bool userGesture,
  ) {
    if (!userGesture) {
      _dispatcher.logNavigation(
        navigation: FirewallSecurityCode.externalAppRequest.code,
        scheme: scheme,
        origin: origin,
        targetType: targetType,
        userGesture: false,
        decision: 'CANCEL_AND_STAY_WEB',
      );
      return NavigationActionPolicy.CANCEL;
    }
    _dispatcher.logNavigation(
      navigation: FirewallSecurityCode.externalAppRequest.code,
      scheme: scheme,
      origin: origin,
      targetType: targetType,
      userGesture: true,
      decision: 'PROMPT_EXTERNAL_APP',
    );
    onExternalPrompt?.call(uri.toString());
    return NavigationActionPolicy.CANCEL;
  }

  Future<NavigationActionPolicy> _handleExternalApp(
    InAppWebViewController controller,
    Uri uri,
    String scheme,
    String origin,
    NavigationTargetType targetType,
    bool userGesture,
  ) async {
    final isTikTok = BrowserNavigationPolicy.isTikTokScheme(scheme);
    final isTrusted = BrowserNavigationPolicy.isTrustedSchemeForOrigin(
      scheme: scheme,
      origin: origin,
    );
    if (isTikTok && isTrusted) {
      return _dispatcher.handleTikTokAppLink(uri, userGesture, origin);
    }
    if (TikTokWebPolicy.isTikTokIntent(uri)) {
      return _dispatcher.handleTikTokIntent(
        controller,
        uri,
        userGesture,
        origin,
      );
    }
    if (!userGesture) {
      _dispatcher.logNavigation(
        navigation: FirewallSecurityCode.externalAppRequest.code,
        scheme: scheme,
        origin: origin,
        targetType: targetType,
        userGesture: false,
        decision: 'STAY_IN_WEB',
      );
      return NavigationActionPolicy.CANCEL;
    }
    if (isTrusted) {
      final launched = await _dispatcher.launchExternalApp(uri);
      _dispatcher.logNavigation(
        navigation: FirewallSecurityCode.externalAppRequest.code,
        scheme: scheme,
        origin: origin,
        targetType: targetType,
        userGesture: true,
        decision:
            launched ? 'LAUNCH_EXTERNAL_INTENT' : 'PROMPT_EXTERNAL_APP',
      );
      if (!launched) onExternalPrompt?.call(uri.toString());
    } else {
      _dispatcher.logNavigation(
        navigation: FirewallSecurityCode.externalAppRequest.code,
        scheme: scheme,
        origin: origin,
        targetType: targetType,
        userGesture: true,
        decision: 'PROMPT_EXTERNAL_APP',
      );
      onExternalPrompt?.call(uri.toString());
    }
    return NavigationActionPolicy.CANCEL;
  }

  NavigationActionPolicy _handleUnsupported(
    Uri uri,
    String scheme,
    String origin,
    NavigationTargetType targetType,
    bool userGesture,
  ) {
    final eval = BrowserSecurityFirewall.evaluateUri(uri);
    if (eval.code == FirewallSecurityCode.blockedScheme) {
      _dispatcher.logNavigation(
        navigation: FirewallSecurityCode.blockedScheme.code,
        scheme: scheme,
        origin: origin,
        targetType: targetType,
        userGesture: userGesture,
        decision: 'BLOCKED',
      );
      _dialogs.showBlocked(
        url: uri.toString(),
        reason: eval.reason ??
            'Esquema local o no permitido bloqueado por seguridad.',
      );
    } else {
      _dispatcher.logNavigation(
        navigation: FirewallSecurityCode.unsupportedScheme.code,
        scheme: scheme,
        origin: origin,
        targetType: targetType,
        userGesture: userGesture,
        decision: 'CANCEL',
      );
    }
    return NavigationActionPolicy.CANCEL;
  }
}
