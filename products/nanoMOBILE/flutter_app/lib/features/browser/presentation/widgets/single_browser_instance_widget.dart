import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/browser_credential_notifier.dart';
import '../../application/browser_tab_notifier.dart';
import '../../application/browser_webview_registry.dart';
import '../../domain/browser_site_profile.dart';
import '../../domain/browser_tab_model.dart';
import '../../infrastructure/browser_scripts.dart';
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

class _SingleBrowserInstanceWidgetState
    extends ConsumerState<SingleBrowserInstanceWidget>
    with
        AutomaticKeepAliveClientMixin<SingleBrowserInstanceWidget>,
        _BrowserInstancePromptState,
        _BrowserInstanceLifecycle {
  @override
  bool get wantKeepAlive => true;

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
