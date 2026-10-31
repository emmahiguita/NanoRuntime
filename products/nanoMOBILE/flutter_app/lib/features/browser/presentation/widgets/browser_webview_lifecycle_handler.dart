// QUÉ: Coordina el ciclo de vida del WebView y eventos de navegación y errores.
// CÓMO: Delega la seguridad en navigation guard, JS handlers y sincronizador de carga.
// POR QUÉ: Permite modularidad, sin cuellos de botella ni procesos zombis (< 160 líneas).

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nanoai/features/browser/application/browser_external_app_behavior.dart';
import 'package:nanoai/features/browser/application/browser_tab_notifier.dart';
import 'package:nanoai/features/browser/application/browser_webview_registry.dart';
import 'package:nanoai/features/browser/domain/browser_tab_model.dart';
import 'package:nanoai/features/browser/presentation/widgets/browser_web_identity_coordinator.dart';
import 'package:nanoai/features/browser/presentation/widgets/browser_webview_js_handlers.dart';
import 'package:nanoai/features/browser/presentation/widgets/browser_webview_load_synchronizer.dart';
import 'package:nanoai/features/browser/presentation/widgets/browser_webview_navigation_guard.dart';
import 'package:nanoai/main.dart';

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

  void onWebViewCreated(InAppWebViewController ctrl) {
    if (!isAlive()) return;
    ref.read(browserWebViewRegistryProvider).attachController(tab.id, ctrl);
    onControllerCreated?.call(ctrl);
    BrowserWebViewJsHandlers.attachHandlers(
      ctrl: ctrl,
      tabId: tab.id,
      ref: ref,
      isAlive: isAlive,
      onZoomChanged: onZoomChanged,
      onPromptSaveCredential: onPromptSaveCredential,
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
