// QUÉ: Despachador de deep links y esquemas de apps externas para Nano Browser.
// CÓMO: Evalúa intenciones de apertura nativa vs permanencia web según ExternalAppBehavior.
// POR QUÉ: Extraído de BrowserWebViewNavigationGuard para cumplir límite de 200 líneas y SRP.

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../domain/browser_navigation_policy.dart';
import '../../domain/tiktok_web_policy.dart';
import '../../infrastructure/browser_security_firewall.dart';

class BrowserExternalAppDispatcher {
  final Future<bool> Function(Uri uri)? externalAppLauncher;
  final ExternalAppBehavior Function()? externalAppBehavior;
  final void Function(String url)? onExternalPrompt;

  const BrowserExternalAppDispatcher({
    this.externalAppLauncher,
    this.externalAppBehavior,
    this.onExternalPrompt,
  });

  void logNavigation({
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

  Future<bool> launchExternalApp(Uri uri) async {
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

  Future<NavigationActionPolicy> handleTikTokAppLink(
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
        final launched = await launchExternalApp(uri);
        logNavigation(
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
        logNavigation(
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
        logNavigation(
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

  Future<NavigationActionPolicy> handleTikTokIntent(
    InAppWebViewController controller,
    Uri uri,
    bool userGesture,
    String origin,
  ) async {
    final fallback = TikTokWebPolicy.extractIntentWebFallback(uri);
    if (fallback != null &&
        BrowserSecurityFirewall.evaluateUri(fallback).isAllowed) {
      logNavigation(
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
    logNavigation(
      navigation: 'TIKTOK_INTENT',
      scheme: uri.scheme,
      origin: origin,
      targetType: NavigationTargetType.externalApp,
      userGesture: userGesture,
      decision: 'STAY_IN_WEB',
    );
    return NavigationActionPolicy.CANCEL;
  }
}
