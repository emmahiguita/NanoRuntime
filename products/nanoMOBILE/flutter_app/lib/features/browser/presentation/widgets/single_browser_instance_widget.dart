import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/browser_credential_notifier.dart';
import '../../application/browser_tab_notifier.dart';
import '../../application/browser_webview_registry.dart';
import '../../domain/browser_site_profile.dart';
import '../../domain/browser_navigation_policy.dart';
import '../../domain/browser_tab_model.dart';
import '../../infrastructure/browser_scripts.dart';
import '../../infrastructure/browser_security_firewall.dart';
import 'browser_oauth_popup_layer.dart';
import 'browser_site_theme.dart';
import 'browser_web_identity_coordinator.dart';
import 'browser_webview_lifecycle_handler.dart';
import 'browser_webview_overlays.dart';
import 'browser_webview_surface.dart';
import 'browser_window_card_frame.dart';

part 'single_browser_instance_lifecycle.part.dart';
part 'single_browser_instance_prompts.part.dart';

/// Instancia nativa única por pestaña y dueña de su estado visual temporal.
///
/// Mantiene la sesión con `keepAlive`, pero delega render, overlays y ciclo de
/// vida para que cada componente tenga una responsabilidad mantenible.
class SingleBrowserInstanceWidget extends ConsumerStatefulWidget {
  const SingleBrowserInstanceWidget({
    super.key,
    required this.tab,
    required this.onToggleMinimize,
    required this.onToggleMaximize,
    required this.onClose,
    this.isMaximized = false,
    this.isMinimized = false,
    this.isCurrentActive = false,
    this.fillHeight = false,
    this.showCardHeader = true,
    this.currentZoom = 1.0,
    this.isDesktopMode = false,
    this.isDarkModeWeb = false,
    this.onSelectTab,
    this.onNavigate,
    this.onControllerCreated,
    this.onExternalPrompt,
    this.dragIndex,
  });

  final BrowserTabModel tab;
  final bool isMaximized;
  final bool isMinimized;
  final bool isCurrentActive;
  final bool fillHeight;
  final bool showCardHeader;
  final bool isDesktopMode;
  final bool isDarkModeWeb;
  final double currentZoom;
  final VoidCallback onToggleMinimize;
  final VoidCallback onToggleMaximize;
  final VoidCallback onClose;
  final VoidCallback? onSelectTab;
  final ValueChanged<String>? onNavigate;
  final ValueChanged<InAppWebViewController>? onControllerCreated;
  final void Function(String url)? onExternalPrompt;
  final int? dragIndex;

  @override
  ConsumerState<SingleBrowserInstanceWidget> createState() =>
      _SingleBrowserInstanceWidgetState();
}

/// Popup OAuth activo para esta instancia de pestaña. Solo uno a la vez.
class _PendingPopup {
  const _PendingPopup({required this.action});

  final CreateWindowAction action;
}

class _SingleBrowserInstanceWidgetState
    extends ConsumerState<SingleBrowserInstanceWidget>
    with
        AutomaticKeepAliveClientMixin<SingleBrowserInstanceWidget>,
        _BrowserInstancePromptState,
        _BrowserInstanceLifecycle {
  @override
  bool get wantKeepAlive => true;

  _PendingPopup? _pendingPopup;

  /// Decide si un `window.open` del WebView puede materializarse como popup.
  ///
  /// Solo proveedores OAuth federados (y popups en blanco con gesto, que usa
  /// Google Identity Services) pasan el firewall; todo lo demás se niega.
  /// Para conservar el comportamiento legado de `target=_blank` en enlaces
  /// normales, esos destinos se recargan en el marco principal.
  Future<bool?> _handleCreateWindow(
    InAppWebViewController controller,
    CreateWindowAction action,
  ) async {
    final uri = action.request.url?.uriValue;
    final evaluation = BrowserSecurityFirewall.evaluatePopupUri(
      uri,
      hasUserGesture: action.hasGesture ?? false,
    );

    debugPrint(
      '[NanoBrowser] popup=${evaluation.isAllowed ? 'ALLOWED' : 'DENIED'} '
      'url=${uri?.origin ?? 'null'} reason=${evaluation.reason ?? evaluation.code.code}',
    );

    if (!evaluation.isAllowed) {
      // target=_blank de páginas comunes: replicar el comportamiento previo
      // de WebView (mismo marco) para no romper enlaces normales.
      if (uri != null &&
          BrowserSecurityFirewall.evaluateUri(uri).isAllowed &&
          BrowserNavigationPolicy.classifyUri(uri) ==
              NavigationTargetType.web) {
        controller.loadUrl(urlRequest: action.request);
      }
      return false;
    }

    if (!mounted || _pendingPopup != null) return false;

    setState(() {
      _pendingPopup = _PendingPopup(action: action);
    });
    return true;
  }

  /// El popup terminó (`window.close()` o cierre manual del usuario).
  ///
  /// [completedByPage] indica que la página cerró el popup tras completar el
  /// login; entonces se recarga el marco principal para que aplique la sesión
  /// recién fijada en las cookies compartidas del WebView.
  void _onPopupClosed({bool completedByPage = false}) {
    debugPrint(
      '[NanoBrowser] popup layer retirada (completado=$completedByPage).',
    );
    final controller = _registry.controllerFor(widget.tab.id);
    if (completedByPage && controller != null) {
      controller.reload();
    }
    if (!mounted) return;
    setState(() => _pendingPopup = null);
  }

  /// Compone la vista nativa y sus capas sin duplicar lógica del controlador.
  @override
  Widget build(BuildContext context) {
    super.build(context);
    final registry = ref.read(browserWebViewRegistryProvider);
    final accent = BrowserSiteTheme.getSiteColor(widget.tab.url);
    final content = Stack(
      fit: StackFit.expand,
      children: [
        BrowserWebViewSurface(
          tab: widget.tab,
          registry: registry,
          handler: _handler,
          generation: _webViewGeneration,
          isFull: widget.isMaximized || widget.fillHeight,
          shouldPause: _shouldPause,
          identity: _identity,
          onProgress: _updateProgress,
          onTitle: _updateTitle,
          onZoomChanged: _triggerZoomBadge,
          onCreateWindow: _handleCreateWindow,
          onCloseWindow: _onPopupClosed,
        ),
        BrowserWebViewOverlays(
          tab: widget.tab,
          accentColor: accent,
          showSaveBanner: _showSaveBanner,
          pendingDomain: _pendingDomain,
          pendingUser: _pendingUser,
          showZoomBadge: _showZoomBadge,
          currentScale: _currentScale,
          onRetry: _retryPage,
          onNavigate: widget.onNavigate,
          onSaveCredential: _confirmSave,
          onDismissCredential: _dismissCredential,
        ),
        if (_pendingPopup != null)
          BrowserOAuthPopupLayer(
            windowId: _pendingPopup!.action.windowId,
            initialRequest: _pendingPopup!.action.request,
            onPopupClosed: () => _onPopupClosed(),
            onPopupCompleted: () => _onPopupClosed(completedByPage: true),
          ),
      ],
    );
    if (!widget.showCardHeader) return content;

    return BrowserWindowCardFrame(
      title: widget.tab.title,
      url: widget.tab.url,
      siteColor: accent,
      isMaximized: widget.isMaximized,
      isMinimized: widget.isMinimized,
      isActive: widget.isCurrentActive,
      fillHeight: widget.fillHeight,
      canGoBack: widget.tab.canGoBack,
      canGoForward: widget.tab.canGoForward,
      dragIndex: widget.dragIndex,
      onReload: _reload,
      onBack: _goBack,
      onForward: _goForward,
      onToggleMinimize: widget.onToggleMinimize,
      onToggleMaximize: widget.onToggleMaximize,
      onClose: widget.onClose,
      onNavigate: widget.onNavigate,
      child: content,
    );
  }
}
