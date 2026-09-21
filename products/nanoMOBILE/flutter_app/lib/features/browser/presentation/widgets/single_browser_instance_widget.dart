import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
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
import 'package:nanoai/features/browser/presentation/widgets/browser_dialog_helper.dart';
import 'package:nanoai/features/browser/presentation/widgets/browser_keep_alive_wrapper.dart';
import 'package:nanoai/features/browser/presentation/widgets/browser_site_theme.dart';
import 'package:nanoai/features/browser/presentation/widgets/browser_webview_lifecycle_handler.dart';
import 'package:nanoai/features/browser/presentation/widgets/browser_window_card_frame.dart';
import 'package:nanoai/features/browser/presentation/widgets/browser_zoom_badge_overlay.dart';
import 'package:nanoai/features/browser/presentation/widgets/browser_owl_assistant_sheet.dart';

/// Instancia y orquestador del ciclo de vida del WebView de una pestaña del navegador.
/// 
/// - ¿Qué hace?: Conecta el motor nativo `InAppWebView` con la bóveda de credenciales,
///   firewall contra SSRF, soporte de zoom táctil, banner de autoguardado y modo escritorio/oscuro.
/// - ¿Cómo funciona?: Registra el controlador en `BrowserWebViewRegistry`, delega eventos de seguridad
///   en `BrowserWebViewLifecycleHandler` y envuelve la vista en `BrowserWindowCardFrame` si se requiere.
/// - ¿Por qué?: Aplica SOLID separando la renderización del marco de ventana de la lógica del WebView.
class SingleBrowserInstanceWidget extends ConsumerStatefulWidget {
  final BrowserTabModel tab;
  final bool isMaximized, isMinimized, isCurrentActive, fillHeight, showCardHeader, isDesktopMode, isDarkModeWeb;
  final double currentZoom;
  final VoidCallback onToggleMinimize, onToggleMaximize, onClose;
  final VoidCallback? onSelectTab;
  final ValueChanged<String>? onNavigate;
  final ValueChanged<InAppWebViewController>? onControllerCreated;
  final void Function(String url)? onExternalPrompt;

  const SingleBrowserInstanceWidget({
    super.key,
    required this.tab,
    this.isMaximized = false,
    this.isMinimized = false,
    this.isCurrentActive = false,
    this.fillHeight = false,
    this.showCardHeader = true,
    this.currentZoom = 1.0,
    this.isDesktopMode = false,
    this.isDarkModeWeb = false,
    required this.onToggleMinimize,
    required this.onToggleMaximize,
    required this.onClose,
    this.onSelectTab,
    this.onNavigate,
    this.onControllerCreated,
    this.onExternalPrompt,
  });

  @override
  ConsumerState<SingleBrowserInstanceWidget> createState() => _SingleBrowserInstanceWidgetState();
}

class _SingleBrowserInstanceWidgetState extends ConsumerState<SingleBrowserInstanceWidget> {
  double _baselineScale = 0.0, _currentScale = 1.0;
  Timer? _zoomBadgeTimer;
  bool _showZoomBadge = false, _showSaveBanner = false;
  String? _pendingDomain, _pendingUser, _pendingPass;

  @override
  void didUpdateWidget(covariant SingleBrowserInstanceWidget old) {
    super.didUpdateWidget(old);
    final ctrl = ref.read(browserWebViewRegistryProvider).controllerFor(widget.tab.id);
    if (widget.tab.url != old.tab.url) ctrl?.loadUrl(urlRequest: URLRequest(url: WebUri(widget.tab.url)));
    if (widget.currentZoom != old.currentZoom) ctrl?.evaluateJavascript(source: BrowserScripts.setZoomLevelScript(widget.currentZoom));
    if (widget.isDarkModeWeb != old.isDarkModeWeb) ctrl?.evaluateJavascript(source: BrowserScripts.toggleDarkModeWebScript);
    if (widget.isDesktopMode != old.isDesktopMode && ctrl != null) {
      _baselineScale = 0.0;
      ctrl.setSettings(settings: InAppWebViewSettings(
        userAgent: widget.isDesktopMode ? BrowserScripts.desktopUserAgent : "",
        preferredContentMode: widget.isDesktopMode ? UserPreferredContentMode.DESKTOP : UserPreferredContentMode.MOBILE,
        useWideViewPort: true, loadWithOverviewMode: true,
      ));
      ctrl.evaluateJavascript(source: widget.isDesktopMode ? BrowserScripts.desktopViewportAdapterScript : BrowserScripts.mobileViewportAdapterScript);
      ctrl.reload();
    }
  }

  @override
  void dispose() {
    _zoomBadgeTimer?.cancel();
    super.dispose();
  }

  void _triggerZoomBadge(double scale) {
    _zoomBadgeTimer?.cancel();
    if (mounted) setState(() { _currentScale = scale; _showZoomBadge = true; });
    _zoomBadgeTimer = Timer(const Duration(milliseconds: 1300), () {
      if (mounted) setState(() => _showZoomBadge = false);
    });
  }

  void _confirmSave() {
    if (_pendingDomain != null && _pendingPass != null) {
      ref.read(browserCredentialProvider.notifier).saveCredential(
        domain: _pendingDomain!, username: _pendingUser ?? '', password: _pendingPass!,
      );
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Contraseña guardada en la bóveda cifrada'), duration: Duration(seconds: 2)));
    }
    setState(() { _showSaveBanner = false; _pendingDomain = null; _pendingUser = null; _pendingPass = null; });
  }

  @override
  Widget build(BuildContext context) {
    final siteColor = BrowserSiteTheme.getSiteColor(widget.tab.url);
    final registry = ref.read(browserWebViewRegistryProvider);
    // isAlive: () => mounted — previene 'ref after disposed' en callbacks async.
    final handler = BrowserWebViewLifecycleHandler(
      getContext: () => context,
      ref: ref,
      tab: widget.tab,
      isDesktopMode: widget.isDesktopMode,
      isDarkModeWeb: widget.isDarkModeWeb,
      currentZoom: widget.currentZoom,
      isAlive: () => mounted,
      onZoomChanged: (z) => _triggerZoomBadge(z),
      onPromptSaveCredential: (d, u, p) {
        if (!mounted || p.isEmpty) return;
        setState(() { _pendingDomain = d.isNotEmpty ? d : (Uri.tryParse(widget.tab.url)?.host ?? ''); _pendingUser = u; _pendingPass = p; _showSaveBanner = true; });
      },
      onControllerCreated: widget.onControllerCreated,
      onExternalPrompt: widget.onExternalPrompt,
    );

    final webViewStack = Stack(
      children: [
        BrowserKeepAliveWrapper(
          child: InAppWebView(
            key: ValueKey('wv_${widget.tab.id}'),
            keepAlive: registry.keepAliveFor(widget.tab.id),
            initialUrlRequest: URLRequest(url: WebUri(widget.tab.url)),
            initialSettings: BrowserSecurityFirewall.createWebViewSettings(
              isDesktopMode: widget.isDesktopMode,
              userAgent: widget.isDesktopMode ? BrowserScripts.desktopUserAgent : null,
            ),
            initialUserScripts: UnmodifiableListView<UserScript>([
              UserScript(source: widget.isDesktopMode ? BrowserScripts.desktopViewportAdapterScript : BrowserScripts.mobileViewportAdapterScript, injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START),
              UserScript(source: BrowserScripts.pinchZoomEngineScript, injectionTime: UserScriptInjectionTime.AT_DOCUMENT_END),
              UserScript(source: BrowserScripts.credentialManagerScript, injectionTime: UserScriptInjectionTime.AT_DOCUMENT_END),
            ]),
            gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer())},
            onWebViewCreated: handler.onWebViewCreated,
            onZoomScaleChanged: (ctrl, oldS, newS) {
              final dpr = MediaQuery.maybeOf(context)?.devicePixelRatio ?? 2.75;
              if (_baselineScale <= 0.0) _baselineScale = dpr > 0.0 ? dpr : (newS > 1.0 ? newS : 1.0);
              final norm = _baselineScale > 0 ? (newS / _baselineScale) : newS;
              _triggerZoomBadge(norm);
              // Guard: widget puede haberse destruido entre frames.
              if (!mounted) return;
              ref.read(browserTabProvider.notifier).updateTabById(widget.tab.id, zoomLevel: norm);
            },
            onLoadStart: handler.onLoadStart,
            onLoadStop: handler.onLoadStop,
            onProgressChanged: (ctrl, p) {
              if (!mounted) return;
              ref.read(browserTabProvider.notifier).updateTabById(widget.tab.id, progress: p / 100.0, isLoading: p < 100);
            },
            onTitleChanged: (ctrl, t) {
              if (t?.isNotEmpty == true && mounted) {
                ref.read(browserTabProvider.notifier).updateTabById(widget.tab.id, title: t);
              }
            },

            shouldOverrideUrlLoading: handler.shouldOverrideUrlLoading,
            onReceivedServerTrustAuthRequest: handler.onReceivedServerTrustAuthRequest,
            onReceivedHttpAuthRequest: handler.onReceivedHttpAuthRequest,
            onSafeBrowsingHit: (c, u, t) async => SafeBrowsingResponse(report: true, action: SafeBrowsingResponseAction.BACK_TO_SAFETY),
            onPermissionRequest: handler.onPermissionRequest,
          ),
        ),
        if (widget.tab.isLoading && widget.tab.progress < 1.0)
          Positioned(top: 0, left: 0, right: 0, child: LinearProgressIndicator(value: widget.tab.progress, minHeight: 2.5, backgroundColor: Colors.transparent, valueColor: AlwaysStoppedAnimation<Color>(siteColor))),
        if (_showSaveBanner && _pendingDomain != null)
          Positioned(top: 4, left: 8, right: 8, child: BrowserCredentialSaveBanner(domain: _pendingDomain!, username: _pendingUser ?? '', onSave: _confirmSave, onDismiss: () => setState(() => _showSaveBanner = false))),
        BrowserZoomBadgeOverlay(visible: _showZoomBadge, scale: _currentScale, accentColor: siteColor),
      ],
    );

    if (!widget.showCardHeader) return webViewStack;

    return BrowserWindowCardFrame(
      title: widget.tab.title, url: widget.tab.url, siteColor: siteColor,
      isMaximized: widget.isMaximized, isMinimized: widget.isMinimized,
      isActive: widget.isCurrentActive, fillHeight: widget.fillHeight,
      onReload: () => ref.read(browserWebViewRegistryProvider).controllerFor(widget.tab.id)?.reload(),
      onBack: () async { final c = ref.read(browserWebViewRegistryProvider).controllerFor(widget.tab.id); if (c != null && await c.canGoBack()) await c.goBack(); },
      onForward: () async { final c = ref.read(browserWebViewRegistryProvider).controllerFor(widget.tab.id); if (c != null && await c.canGoForward()) await c.goForward(); },
      onAskOwl: () => BrowserOwlAssistantSheet.show(
        context, tab: widget.tab,
        controller: ref.read(browserWebViewRegistryProvider).controllerFor(widget.tab.id),
      ),
      onToggleMinimize: widget.onToggleMinimize, onToggleMaximize: widget.onToggleMaximize,
      onClose: widget.onClose,
      onTitleTap: () => widget.onNavigate != null
          ? BrowserDialogHelper.showUrlEditDialog(context: context, currentUrl: widget.tab.url, onSubmitted: widget.onNavigate!)
          : widget.onSelectTab?.call(),
      child: webViewStack,
    );
  }
}
