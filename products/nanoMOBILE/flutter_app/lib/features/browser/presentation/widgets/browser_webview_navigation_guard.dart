import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../domain/browser_navigation_policy.dart';
import '../../domain/tiktok_web_policy.dart';
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
    this.externalAppLauncher,
    this.externalAppBehavior,
  }) : _dialogs = BrowserWebViewDialogGuard(
         context: context,
         ref: ref,
         isAlive: isAlive,
       );

  final bool Function() isAlive;
  final BrowserWebIdentityCoordinator identity;
  final void Function(String url)? onExternalPrompt;
  final Future<bool> Function(Uri uri)? externalAppLauncher;

  /// Modo configurado para deep links de apps externas (STAY_IN_WEB default).
  final ExternalAppBehavior Function()? externalAppBehavior;
  final BrowserWebViewDialogGuard _dialogs;

  void _logNavigation({
    required String navigation,
    required String scheme,
    required String origin,
    required NavigationTargetType targetType,
    required bool userGesture,
    required String decision,
  }) {
    debugPrint(
      '[NanoBrowser][Navigation] origin=$origin scheme=$scheme '
      'targetType=${targetType.name} gesture=$userGesture '
      'decision=$decision code=$navigation',
    );
  }

  Future<bool> _launchExternalApp(Uri uri) async {
    if (externalAppLauncher != null) {
      return externalAppLauncher!(uri);
    }
    try {
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
    return false;
  }

  /// Contiene los deep links de TikTok Web según el modo configurado.
  ///
  /// STAY_IN_WEB (default) cancela en silencio: sin modal de firewall, sin
  /// "¿Abrir TikTok?" y sin lanzamiento automático de la app nativa.
  Future<NavigationActionPolicy> _handleTikTokAppLink(
    Uri uri,
    bool userGesture,
    String origin,
  ) async {
    final behavior =
        externalAppBehavior?.call() ?? ExternalAppBehavior.stayInWeb;
    final decision = TikTokWebPolicy.decideAppScheme(
      uri: uri,
      hasGesture: userGesture,
      behavior: behavior,
    );

    switch (decision) {
      case TikTokNavigationDecision.openExternalExplicitly:
        final launched = await _launchExternalApp(uri);
        _logNavigation(
          navigation: FirewallSecurityCode.externalAppRequest.code,
          scheme: uri.scheme,
          origin: origin,
          targetType: NavigationTargetType.externalApp,
          userGesture: userGesture,
          decision: launched
              ? 'LAUNCH_EXTERNAL_INTENT'
              : 'STAY_WEB_APP_NOT_INSTALLED',
        );
        return NavigationActionPolicy.CANCEL;

      case TikTokNavigationDecision.askUser:
        _logNavigation(
          navigation: FirewallSecurityCode.externalAppRequest.code,
          scheme: uri.scheme,
          origin: origin,
          targetType: NavigationTargetType.externalApp,
          userGesture: userGesture,
          decision: 'PROMPT_EXTERNAL_APP',
        );
        onExternalPrompt?.call(uri.toString());
        return NavigationActionPolicy.CANCEL;

      case TikTokNavigationDecision.allowWeb:
      case TikTokNavigationDecision.stayInWeb:
      case TikTokNavigationDecision.blockSecurityThreat:
        _logNavigation(
          navigation: 'TIKTOK_APP_LINK',
          scheme: uri.scheme,
          origin: origin,
          targetType: NavigationTargetType.externalApp,
          userGesture: userGesture,
          decision: 'STAY_IN_WEB',
        );
        return NavigationActionPolicy.CANCEL;
    }
  }

  /// intent:// de TikTok: carga el fallback web si existe; si no, se queda en
  /// la página actual sin salir del WebView.
  Future<NavigationActionPolicy> _handleTikTokIntent(
    InAppWebViewController controller,
    Uri uri,
    bool userGesture,
    String origin,
  ) async {
    final fallback = TikTokWebPolicy.extractIntentWebFallback(uri);
    if (fallback != null &&
        BrowserSecurityFirewall.evaluateUri(fallback).isAllowed) {
      _logNavigation(
        navigation: 'TIKTOK_INTENT',
        scheme: uri.scheme,
        origin: origin,
        targetType: NavigationTargetType.externalApp,
        userGesture: userGesture,
        decision: 'LOAD_WEB_FALLBACK',
      );
      controller.loadUrl(
        urlRequest: URLRequest(url: WebUri(fallback.toString())),
      );
      return NavigationActionPolicy.CANCEL;
    }
    _logNavigation(
      navigation: 'TIKTOK_INTENT',
      scheme: uri.scheme,
      origin: origin,
      targetType: NavigationTargetType.externalApp,
      userGesture: userGesture,
      decision: 'STAY_IN_WEB',
    );
    return NavigationActionPolicy.CANCEL;
  }

  /// Detiene una carga principal que no cumple la política del firewall.
  bool allowsLoad(InAppWebViewController controller, String url) {
    final uri = Uri.tryParse(url.trim());
    if (uri == null) {
      controller.stopLoading();
      return false;
    }

    final targetType = BrowserNavigationPolicy.classifyUri(uri);

    if (targetType == NavigationTargetType.web) {
      final evaluation = BrowserSecurityFirewall.evaluateUri(uri);
      if (evaluation.isAllowed) return true;
      controller.stopLoading();
      _dialogs.showBlocked(
        url: url,
        reason: evaluation.reason ??
            'Dirección privada, puerto interno o protocolo no seguro bloqueado.',
      );
      return false;
    }

    if (targetType == NavigationTargetType.internalWeb) {
      if (uri.scheme.toLowerCase() == 'about' &&
          uri.path != 'blank' &&
          uri.toString() != 'about:blank') {
        controller.stopLoading();
        _dialogs.showBlocked(
          url: url,
          reason: 'Recurso about interno no permitido.',
        );
        return false;
      }
      return true;
    }

    // Esquemas de apps externas o personalizados no deben cargarse en el WebView
    // pero tampoco deben catalogarse erróneamente como peligro de red privada.
    controller.stopLoading();
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

    final scheme = uri.scheme.toLowerCase();
    final userGesture = action.hasGesture ?? false;

    // Obtener origen actual de la navegación sin exponer parámetros sensibles
    final currentWebUri = await controller.getUrl();
    final origin = BrowserNavigationPolicy.extractOrigin(
      currentWebUri?.uriValue,
      headers: action.request.headers,
    );

    final targetType = BrowserNavigationPolicy.classifyUri(uri);

    switch (targetType) {
      case NavigationTargetType.web:
        final evaluation = BrowserSecurityFirewall.evaluateUri(uri);
        if (!evaluation.isAllowed) {
          _logNavigation(
            navigation: evaluation.code.code,
            scheme: scheme,
            origin: origin,
            targetType: targetType,
            userGesture: userGesture,
            decision: 'BLOCKED',
          );
          _dialogs.showBlocked(
            url: uri.toString(),
            reason: evaluation.reason ??
                'Dirección privada, puerto interno o protocolo no seguro bloqueado.',
          );
          return NavigationActionPolicy.CANCEL;
        }

        // Si la carga web es permitida, verificar si requiere interceptación de identidad
        if (await identity.intercept(controller, action.request)) {
          _logNavigation(
            navigation: 'WEB_IDENTITY_INTERCEPT',
            scheme: scheme,
            origin: origin,
            targetType: targetType,
            userGesture: userGesture,
            decision: 'IDENTITY_INTERCEPT',
          );
          return NavigationActionPolicy.CANCEL;
        }

        _logNavigation(
          navigation: 'WEB_ALLOWED',
          scheme: scheme,
          origin: origin,
          targetType: targetType,
          userGesture: userGesture,
          decision: 'ALLOW',
        );
        return NavigationActionPolicy.ALLOW;

      case NavigationTargetType.internalWeb:
        if (scheme == 'about') {
          if (uri.path == 'blank' || uri.toString() == 'about:blank') {
            _logNavigation(
              navigation: 'INTERNAL_WEB_ALLOWED',
              scheme: scheme,
              origin: origin,
              targetType: targetType,
              userGesture: userGesture,
              decision: 'ALLOW',
            );
            return NavigationActionPolicy.ALLOW;
          }
          _logNavigation(
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

        _logNavigation(
          navigation: 'INTERNAL_WEB_ALLOWED',
          scheme: scheme,
          origin: origin,
          targetType: targetType,
          userGesture: userGesture,
          decision: 'ALLOW',
        );
        return NavigationActionPolicy.ALLOW;

      case NavigationTargetType.phone:
      case NavigationTargetType.email:
      case NavigationTargetType.store:
        if (!userGesture) {
          _logNavigation(
            navigation: FirewallSecurityCode.externalAppRequest.code,
            scheme: scheme,
            origin: origin,
            targetType: targetType,
            userGesture: false,
            decision: 'CANCEL_AND_STAY_WEB',
          );
          return NavigationActionPolicy.CANCEL;
        }

        _logNavigation(
          navigation: FirewallSecurityCode.externalAppRequest.code,
          scheme: scheme,
          origin: origin,
          targetType: targetType,
          userGesture: true,
          decision: 'PROMPT_EXTERNAL_APP',
        );
        onExternalPrompt?.call(uri.toString());
        return NavigationActionPolicy.CANCEL;

      case NavigationTargetType.externalApp:
        final isTikTok = BrowserNavigationPolicy.isTikTokScheme(scheme);
        final isTrustedOrigin = BrowserNavigationPolicy.isTrustedSchemeForOrigin(
          scheme: scheme,
          origin: origin,
        );

        // Deep link de TikTok Web hacia su app nativa: contener en web según
        // el modo configurado (STAY_IN_WEB por defecto, sin modales).
        if (isTikTok && isTrustedOrigin) {
          return _handleTikTokAppLink(uri, userGesture, origin);
        }

        // intent:// de TikTok: usar el fallback web si existe; si no, quedarse
        // en la página actual sin salir del WebView.
        if (TikTokWebPolicy.isTikTokIntent(uri)) {
          return _handleTikTokIntent(controller, uri, userGesture, origin);
        }

        // Otros esquemas de aplicación externa
        if (!userGesture) {
          _logNavigation(
            navigation: FirewallSecurityCode.externalAppRequest.code,
            scheme: scheme,
            origin: origin,
            targetType: targetType,
            userGesture: false,
            decision: 'STAY_IN_WEB',
          );
          return NavigationActionPolicy.CANCEL;
        }

        if (isTrustedOrigin) {
          final launched = await _launchExternalApp(uri);
          _logNavigation(
            navigation: FirewallSecurityCode.externalAppRequest.code,
            scheme: scheme,
            origin: origin,
            targetType: targetType,
            userGesture: true,
            decision: launched
                ? 'LAUNCH_EXTERNAL_INTENT'
                : 'PROMPT_EXTERNAL_APP',
          );
          if (!launched) {
            onExternalPrompt?.call(uri.toString());
          }
        } else {
          _logNavigation(
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

      case NavigationTargetType.unsupported:
        final evaluation = BrowserSecurityFirewall.evaluateUri(uri);
        if (evaluation.code == FirewallSecurityCode.blockedScheme) {
          _logNavigation(
            navigation: FirewallSecurityCode.blockedScheme.code,
            scheme: scheme,
            origin: origin,
            targetType: targetType,
            userGesture: userGesture,
            decision: 'BLOCKED',
          );
          _dialogs.showBlocked(
            url: uri.toString(),
            reason: evaluation.reason ??
                'Esquema local o no permitido bloqueado por seguridad.',
          );
        } else {
          _logNavigation(
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
