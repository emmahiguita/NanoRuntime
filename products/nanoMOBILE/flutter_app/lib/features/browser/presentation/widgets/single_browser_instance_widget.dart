import 'dart:async';
import 'dart:collection';
import 'browser_webview_appearance_sync.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nanoai/features/browser/application/browser_credential_notifier.dart';
import 'package:nanoai/features/browser/application/browser_tab_notifier.dart';
import 'package:nanoai/features/browser/application/browser_webview_registry.dart';
import 'package:nanoai/features/browser/domain/browser_tab_model.dart';
import 'package:nanoai/features/browser/infrastructure/browser_scripts.dart';
import 'package:nanoai/features/browser/infrastructure/browser_security_firewall.dart';
import 'package:nanoai/features/browser/presentation/widgets/browser_credential_save_banner.dart';
import 'package:nanoai/features/browser/presentation/widgets/browser_gesture_arena.dart';
import 'package:nanoai/features/browser/presentation/widgets/browser_keep_alive_wrapper.dart';
import 'package:nanoai/features/browser/presentation/widgets/browser_site_theme.dart';
import 'package:nanoai/features/browser/presentation/widgets/browser_webview_lifecycle_handler.dart';
import 'package:nanoai/features/browser/presentation/widgets/browser_window_card_frame.dart';
import 'package:nanoai/features/browser/presentation/widgets/browser_zoom_badge_overlay.dart';
import 'package:nanoai/features/browser/presentation/widgets/browser_owl_assistant_sheet.dart';

/// Instancia nativa única por pestaña con soporte de rotación fluida portrait/landscape.
/// 
/// - QUÉ HACE: Renderiza la plataforma InAppWebView conservando sesión de audio y renderizado.
/// - CÓMO FUNCIONA: En [didChangeDependencies], detecta cambios de orientación y despacha
///   'resize' en JavaScript manteniendo el hilo nativo de audio/video activo sin destruir el canvas.
/// - POR QUÉ: Previene la pantalla negra y pérdida de sonido al rotar el dispositivo (<200 líneas).
class SingleBrowserInstanceWidget extends ConsumerStatefulWidget {
  final BrowserTabModel tab;
  final bool isMaximized, isMinimized, isCurrentActive, fillHeight, showCardHeader, isDesktopMode, isDarkModeWeb;
  final double currentZoom;
  final VoidCallback onToggleMinimize, onToggleMaximize, onClose;
  final VoidCallback? onSelectTab;
  final ValueChanged<String>? onNavigate;
  final ValueChanged<InAppWebViewController>? onControllerCreated;
  final void Function(String url)? onExternalPrompt;
  final int? dragIndex;

  const SingleBrowserInstanceWidget({
    super.key, required this.tab, this.isMaximized = false, this.isMinimized = false,
    this.isCurrentActive = false, this.fillHeight = false, this.showCardHeader = true,
    this.currentZoom = 1.0, this.isDesktopMode = false, this.isDarkModeWeb = false,
    required this.onToggleMinimize, required this.onToggleMaximize, required this.onClose,
    this.onSelectTab, this.onNavigate, this.onControllerCreated, this.onExternalPrompt, this.dragIndex,
  });

  @override
  ConsumerState<SingleBrowserInstanceWidget> createState() => _SingleBrowserInstanceWidgetState();
}

class _SingleBrowserInstanceWidgetState extends ConsumerState<SingleBrowserInstanceWidget> {
  Timer? _zoomBadgeTimer;
  bool _showZoomBadge = false, _showSaveBanner = false;
  double _currentScale = 1.0;
  String? _pendingDomain, _pendingUser, _pendingPass;
  Orientation? _lastOrientation;
  late BrowserWebViewLifecycleHandler _handler;
  final _appearance = BrowserWebViewAppearanceSync();

  @override
  void initState() {
    super.initState();
    _buildHandler();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final currentOri = MediaQuery.of(context).orientation;
    if (_lastOrientation != null && _lastOrientation != currentOri) {
      final ctrl = ref.read(browserWebViewRegistryProvider).controllerFor(widget.tab.id);
      if (ctrl != null) {
        ctrl.evaluateJavascript(source: 'window.dispatchEvent(new Event("resize"));');
        if (!widget.isMinimized) ctrl.resume();
      }
    }
    _lastOrientation = currentOri;
  }

  @override
  void didUpdateWidget(covariant SingleBrowserInstanceWidget old) {
    super.didUpdateWidget(old);
    final registry = ref.read(browserWebViewRegistryProvider);
    final ctrl = registry.controllerFor(widget.tab.id);
    if (old.isMinimized != widget.isMinimized) {
      if (widget.isMinimized) { registry.pauseTab(widget.tab.id); } else { registry.resumeTab(widget.tab.id); }
    }
    _handler..tab = widget.tab..isDesktopMode = widget.isDesktopMode
      ..isDarkModeWeb = widget.isDarkModeWeb..currentZoom = widget.currentZoom;
    if (widget.tab.url != old.tab.url && widget.tab.url != _handler.reportedUrl) {
      ctrl?.loadUrl(urlRequest: URLRequest(url: WebUri(widget.tab.url)));
    }
    if (widget.tab.zoomLevel != old.tab.zoomLevel) ctrl?.evaluateJavascript(source: BrowserScripts.setZoomLevelScript(widget.tab.zoomLevel));
    if (widget.isDarkModeWeb != old.isDarkModeWeb) ctrl?.evaluateJavascript(source: BrowserScripts.toggleDarkModeWebScript);
    if (widget.isDesktopMode != old.isDesktopMode && ctrl != null) {
      _appearance.apply(ctrl, desktop: widget.isDesktopMode, isAlive: () => mounted);
    }
  }

  void _buildHandler() {
    _handler = BrowserWebViewLifecycleHandler(
      getContext: () => context, ref: ref, tab: widget.tab,
      isDesktopMode: widget.isDesktopMode, isDarkModeWeb: widget.isDarkModeWeb,
      currentZoom: widget.currentZoom, isAlive: () => mounted,
      onZoomChanged: (z) => _triggerZoomBadge(z),
      onPromptSaveCredential: (d, u, p) {
        if (!mounted || p.isEmpty) return;
        setState(() {
          _pendingDomain = d.isNotEmpty ? d : (Uri.tryParse(widget.tab.url)?.host ?? '');
          _pendingUser = u; _pendingPass = p; _showSaveBanner = true;
        });
      },
      onControllerCreated: widget.onControllerCreated, onExternalPrompt: widget.onExternalPrompt,
    );
  }

  @override
  void dispose() {
    _zoomBadgeTimer?.cancel();
    super.dispose();
  }

  void _triggerZoomBadge(double scale) {
    if (!mounted) return;
    _zoomBadgeTimer?.cancel();
    setState(() { _currentScale = scale; _showZoomBadge = true; });
    _zoomBadgeTimer = Timer(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _showZoomBadge = false);
    });
  }

  void _confirmSave() {
    if (_pendingDomain != null && _pendingPass != null) {
      ref.read(browserCredentialProvider.notifier).saveCredential(domain: _pendingDomain!, username: _pendingUser ?? '', password: _pendingPass!);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Contraseña guardada'), duration: Duration(seconds: 2)));
    }
    setState(() { _showSaveBanner = false; _pendingDomain = null; _pendingUser = null; _pendingPass = null; });
  }

  @override
  Widget build(BuildContext context) {
    final siteColor = BrowserSiteTheme.getSiteColor(widget.tab.url);
    final registry = ref.read(browserWebViewRegistryProvider);
    final isFull = widget.isMaximized || widget.fillHeight;

    final webViewStack = Stack(children: [
      BrowserKeepAliveWrapper(child: InAppWebView(
        key: ValueKey('wv_${widget.tab.id}'),
        keepAlive: registry.keepAliveFor(widget.tab.id),
        initialUrlRequest: URLRequest(url: WebUri(widget.tab.url)),
        initialSettings: BrowserSecurityFirewall.createWebViewSettings(
          isDesktopMode: widget.isDesktopMode, userAgent: widget.isDesktopMode ? BrowserScripts.desktopUserAgent : null,
        ),
        initialUserScripts: UnmodifiableListView<UserScript>([
          if (widget.isDesktopMode) BrowserWebViewAppearanceSync.viewportScript(true),
          UserScript(source: BrowserScripts.pinchZoomEngineScript, injectionTime: UserScriptInjectionTime.AT_DOCUMENT_END),
          UserScript(source: BrowserScripts.credentialManagerScript, injectionTime: UserScriptInjectionTime.AT_DOCUMENT_END),
        ]),
        gestureRecognizers: BrowserGestureArena.buildGestureRecognizers(isMaximized: isFull, isInteractive: true),
        onWebViewCreated: (ctrl) {
          _handler.onWebViewCreated(ctrl);
          if (widget.isMinimized) { registry.pauseTab(widget.tab.id); } else { registry.resumeTab(widget.tab.id); }
        },
        onZoomScaleChanged: (ctrl, oldS, newS) => _triggerZoomBadge(newS),
        onLoadStart: _handler.onLoadStart, onLoadStop: _handler.onLoadStop,
        onProgressChanged: (ctrl, p) { if (mounted) ref.read(browserTabProvider.notifier).updateTabById(widget.tab.id, progress: p / 100.0, isLoading: p < 100); },
        onTitleChanged: (ctrl, t) { if (t?.isNotEmpty == true && mounted) ref.read(browserTabProvider.notifier).updateTabById(widget.tab.id, title: t); },
        shouldOverrideUrlLoading: _handler.shouldOverrideUrlLoading,
        onReceivedServerTrustAuthRequest: _handler.onReceivedServerTrustAuthRequest,
        onReceivedHttpAuthRequest: _handler.onReceivedHttpAuthRequest,
        onPermissionRequest: _handler.onPermissionRequest,
      )),
      if (widget.tab.isLoading && widget.tab.progress < 1.0) Positioned(top: 0, left: 0, right: 0, child: LinearProgressIndicator(
        value: widget.tab.progress, minHeight: 2.0, backgroundColor: Colors.transparent, valueColor: AlwaysStoppedAnimation<Color>(siteColor),
      )),
      if (_showSaveBanner && _pendingDomain != null) Positioned(top: 4, left: 8, right: 8, child: BrowserCredentialSaveBanner(
        domain: _pendingDomain!, username: _pendingUser ?? '', onSave: _confirmSave, onDismiss: () => setState(() => _showSaveBanner = false),
      )),
      BrowserZoomBadgeOverlay(visible: _showZoomBadge, scale: _currentScale, accentColor: siteColor),
    ]);

    if (!widget.showCardHeader) return webViewStack;

    return BrowserWindowCardFrame(
      title: widget.tab.title, url: widget.tab.url, siteColor: siteColor,
      isMaximized: widget.isMaximized, isMinimized: widget.isMinimized,
      isActive: widget.isCurrentActive, fillHeight: widget.fillHeight,
      canGoBack: widget.tab.canGoBack, canGoForward: widget.tab.canGoForward, dragIndex: widget.dragIndex,
      onReload: () => registry.controllerFor(widget.tab.id)?.reload(),
      onBack: () async { final c = registry.controllerFor(widget.tab.id); if (c != null && await c.canGoBack()) await c.goBack(); },
      onForward: () async { final c = registry.controllerFor(widget.tab.id); if (c != null && await c.canGoForward()) await c.goForward(); },
      onAskOwl: () => BrowserOwlAssistantSheet.show(context, tab: widget.tab, controller: registry.controllerFor(widget.tab.id)),
      onToggleMinimize: widget.onToggleMinimize, onToggleMaximize: widget.onToggleMaximize,
      onClose: widget.onClose, onNavigate: widget.onNavigate, child: webViewStack,
    );
  }
}
