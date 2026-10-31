// QUÉ: Aplica la política de navegación y permisos de seguridad sin mezclarla con la carga.
// CÓMO: Evalúa URLs contra BrowserSecurityFirewall, intercepta identidad y delega diálogos y apps externas.
// POR QUÉ: Puerta única de seguridad reutilizable, robusta y con Clean Architecture (< 180 líneas).

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/browser_navigation_policy.dart';
import '../../domain/tiktok_web_policy.dart';
import '../../infrastructure/browser_security_firewall.dart';
import 'browser_external_app_dispatcher.dart';
import 'browser_web_identity_coordinator.dart';
import 'browser_webview_dialog_guard.dart';

part 'browser_navigation_guard_handlers.part.dart';

class BrowserWebViewNavigationGuard {
  BrowserWebViewNavigationGuard({
    required BuildContext Function() context,
    required WidgetRef ref,
    required this.isAlive,
    required this.identity,
    this.onExternalPrompt,
    this.externalAppLauncher,
    this.externalAppBehavior,
  })  : _dialogs = BrowserWebViewDialogGuard(
          context: context,
          ref: ref,
          isAlive: isAlive,
        ),
        _dispatcher = BrowserExternalAppDispatcher(
          externalAppLauncher: externalAppLauncher,
          externalAppBehavior: externalAppBehavior,
          onExternalPrompt: onExternalPrompt,
        );

  final bool Function() isAlive;
  final BrowserWebIdentityCoordinator identity;
  final void Function(String url)? onExternalPrompt;
  final Future<bool> Function(Uri uri)? externalAppLauncher;
  final ExternalAppBehavior Function()? externalAppBehavior;
  final BrowserWebViewDialogGuard _dialogs;
  final BrowserExternalAppDispatcher _dispatcher;

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
    controller.stopLoading();
    return false;
  }

  Future<NavigationActionPolicy> shouldOverrideUrlLoading(
    InAppWebViewController controller,
    NavigationAction action,
  ) async {
    if (!isAlive()) return NavigationActionPolicy.CANCEL;
    final uri = action.request.url?.uriValue;
    if (uri == null) return NavigationActionPolicy.CANCEL;

    final scheme = uri.scheme.toLowerCase();
    final userGesture = action.hasGesture ?? false;
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
          _dispatcher.logNavigation(
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
        if (await identity.intercept(controller, action.request)) {
          _dispatcher.logNavigation(
            navigation: 'WEB_IDENTITY_INTERCEPT',
            scheme: scheme,
            origin: origin,
            targetType: targetType,
            userGesture: userGesture,
            decision: 'IDENTITY_INTERCEPT',
          );
          return NavigationActionPolicy.CANCEL;
        }
        _dispatcher.logNavigation(
          navigation: 'WEB_ALLOWED',
          scheme: scheme,
          origin: origin,
          targetType: targetType,
          userGesture: userGesture,
          decision: 'ALLOW',
        );
        return NavigationActionPolicy.ALLOW;

      case NavigationTargetType.internalWeb:
        return _handleInternalWeb(uri, scheme, origin, targetType, userGesture);

      case NavigationTargetType.phone:
      case NavigationTargetType.email:
      case NavigationTargetType.store:
        return _handleIntentScheme(
          uri,
          scheme,
          origin,
          targetType,
          userGesture,
        );

      case NavigationTargetType.externalApp:
        return _handleExternalApp(
          controller,
          uri,
          scheme,
          origin,
          targetType,
          userGesture,
        );

      case NavigationTargetType.unsupported:
        return _handleUnsupported(
          uri,
          scheme,
          origin,
          targetType,
          userGesture,
        );
    }
  }

  Future<ServerTrustAuthResponse?> requestServerTrust(
    InAppWebViewController controller,
    URLAuthenticationChallenge challenge,
  ) =>
      _dialogs.requestServerTrust(challenge);

  Future<HttpAuthResponse?> requestHttpAuth(
    InAppWebViewController controller,
    URLAuthenticationChallenge challenge,
  ) =>
      _dialogs.requestHttpAuth(challenge);

  Future<PermissionResponse> requestPermission(
    InAppWebViewController controller,
    PermissionRequest request,
  ) =>
      _dialogs.requestPermission(request);
}
