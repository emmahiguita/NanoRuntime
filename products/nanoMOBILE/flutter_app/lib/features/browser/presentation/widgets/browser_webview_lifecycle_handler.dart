import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nanoai/features/browser/application/browser_external_app_behavior.dart';
import 'package:nanoai/features/browser/application/browser_tab_notifier.dart';
import 'package:nanoai/features/browser/application/browser_webview_registry.dart';
import 'package:nanoai/features/browser/domain/browser_navigation_policy.dart';
import 'package:nanoai/features/browser/domain/browser_tab_model.dart';
import 'package:nanoai/features/browser/presentation/widgets/browser_web_identity_coordinator.dart';
import 'package:nanoai/features/browser/presentation/widgets/browser_webview_load_synchronizer.dart';
import 'package:nanoai/features/browser/presentation/widgets/browser_webview_navigation_guard.dart';
import 'package:nanoai/main.dart';

/// QUÉ HACE:
/// Coordina el ciclo de vida del WebView y los handlers de JavaScript (`nanoZoomUpdate`,
/// `nanoSaveCredential`), delegando políticas de navegación a [navigation].
///
/// CÓMO FUNCIONA:
/// Valida en el lado nativo (`ctrl.getUrl()`) que toda solicitud de guardado de credenciales
/// provenga de un origen `https:` real, coincidente con la pestaña activa y no perteneciente
/// a WhatsApp Web ni a proveedores OAuth.
///
/// POR QUÉ:
/// Impide suplantación de origen en el puente JS (OWASP MASTG) y mantiene < 200 líneas.
class BrowserWebViewLifecycleHandler {
  final BuildContext Function() getContext;
  final WidgetRef ref;
  BrowserTabModel tab;
  String? reportedUrl;
  int _loadGeneration = 0;
  bool isDarkModeWeb;
  final BrowserWebIdentityCoordinator identity;
  double currentZoom;
  final void Function(double scale) onZoomChanged;
  final void Function(String domain, String username, String password)
  onPromptSaveCredential;
  final VoidCallback onRenderProcessLost;
  final ValueChanged<InAppWebViewController>? onControllerCreated;
  final void Function(String url)? onExternalPrompt;
  final bool Function() isAlive;
  late final BrowserWebViewNavigationGuard navigation;

  BrowserWebViewLifecycleHandler({
    required this.getContext,
    required this.ref,
    required this.tab,
    required this.identity,
    required this.isDarkModeWeb,
    required this.currentZoom,
    required this.onZoomChanged,
    required this.onPromptSaveCredential,
    required this.onRenderProcessLost,
    required this.isAlive,
    this.onControllerCreated,
    this.onExternalPrompt,
  }) {
    navigation = BrowserWebViewNavigationGuard(
      context: getContext,
      ref: ref,
      isAlive: isAlive,
      identity: identity,
      onExternalPrompt: onExternalPrompt,
      externalAppBehavior: () => ref.read(browserExternalAppBehaviorProvider),
    );
  }

  static bool _isExcludedCredentialHost(String host) {
    final h = host.trim().toLowerCase();
    if (h.isEmpty) return true;
    if (h == 'web.whatsapp.com' ||
        h == 'whatsapp.com' ||
        h.endsWith('.whatsapp.com')) {
      return true;
    }
    return BrowserNavigationPolicy.isOAuthProviderHost(h);
  }

  void onWebViewCreated(InAppWebViewController ctrl) {
    if (!isAlive()) return;
    ref.read(browserWebViewRegistryProvider).attachController(tab.id, ctrl);
    onControllerCreated?.call(ctrl);
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
            .updateTabById(tab.id, zoomLevel: z);
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
        final claimedHost = (args[0]?.toString() ?? '').trim().toLowerCase();
        if (scheme != 'https' || _isExcludedCredentialHost(actualHost)) {
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
    audioHandler.attachSource(tab.id, ctrl);
  }

  void onLoadStart(InAppWebViewController ctrl, WebUri? url) {
    audioHandler.clearSource(tab.id);
    if (url == null || !isAlive()) return;
    ++_loadGeneration;
    final urlStr = reportedUrl = url.toString();
    if (!navigation.allowsLoad(ctrl, urlStr)) return;
    ref.read(browserTabProvider.notifier).updateTabById(
      tab.id,
      url: urlStr,
      isLoading: true,
      progress: 0.1,
      clearError: true,
    );
  }

  Future<void> onLoadStop(InAppWebViewController ctrl, WebUri? url) async {
    final generation = _loadGeneration;
    await BrowserWebViewLoadSynchronizer(
      ref: ref,
      tab: tab,
      isDesktopMode: identity.usesDesktop(url?.toString() ?? tab.url),
      isDarkModeWeb: isDarkModeWeb,
      currentZoom: currentZoom,
      isAlive: () => isAlive() && generation == _loadGeneration,
    ).synchronize(ctrl, url);
  }

  void onReceivedError(
    InAppWebViewController ctrl,
    WebResourceRequest request,
    WebResourceError error,
  ) {
    if (!isAlive() || !(request.isForMainFrame ?? true)) return;
    ref.read(browserTabProvider.notifier).updateTabById(
      tab.id,
      hasError: true,
      errorMessage: error.description,
      isLoading: false,
      progress: 0.0,
    );
  }

  void onReceivedHttpError(
    InAppWebViewController ctrl,
    WebResourceRequest request,
    WebResourceResponse res,
  ) {
    if (!isAlive() || !(request.isForMainFrame ?? true)) return;
    final code = res.statusCode ?? 0;
    if (code >= 400) {
      ref.read(browserTabProvider.notifier).updateTabById(
        tab.id,
        hasError: true,
        errorCode: code,
        errorMessage: res.reasonPhrase ?? 'Error HTTP $code',
        isLoading: false,
      );
    }
  }

  void onUpdateVisitedHistory(
    InAppWebViewController ctrl,
    WebUri? url,
    bool? isReload,
  ) async {
    if (!isAlive() || url == null) return;
    final urlStr = reportedUrl = url.toString();
    try {
      final canBack = await ctrl.canGoBack();
      final canFwd = await ctrl.canGoForward();
      if (!isAlive()) return;
      ref.read(browserTabProvider.notifier).updateTabById(
        tab.id,
        url: urlStr,
        canGoBack: canBack,
        canGoForward: canFwd,
      );
    } catch (_) {}
  }

  void onRenderProcessGone(
    InAppWebViewController ctrl,
    RenderProcessGoneDetail detail,
  ) {
    audioHandler.clearSource(tab.id);
    if (isAlive()) {
      ref.read(browserTabProvider.notifier).updateTabById(
        tab.id,
        hasError: true,
        errorMessage: detail.didCrash
            ? 'El proceso de la página se cerró inesperadamente.'
            : 'Android liberó el proceso de la página para recuperar memoria.',
        isLoading: false,
      );
    }
    onRenderProcessLost();
  }
}
