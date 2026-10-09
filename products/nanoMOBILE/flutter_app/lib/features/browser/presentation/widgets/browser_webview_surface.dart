import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../../application/browser_webview_registry.dart';
import '../../domain/browser_tab_model.dart';
import '../../infrastructure/browser_scripts.dart';
import '../../infrastructure/browser_security_firewall.dart';
import 'browser_gesture_arena.dart';
import 'browser_keep_alive_wrapper.dart';
import 'browser_web_identity_coordinator.dart';
import 'browser_webview_lifecycle_handler.dart';

/// Monta exclusivamente la vista nativa y conecta sus eventos reales.
class BrowserWebViewSurface extends StatelessWidget {
  const BrowserWebViewSurface({
    super.key,
    required this.tab,
    required this.registry,
    required this.handler,
    required this.generation,
    required this.isFull,
    required this.shouldPause,
    required this.identity,
    required this.onProgress,
    required this.onTitle,
    required this.onZoomChanged,
  });

  final BrowserTabModel tab;
  final BrowserWebViewRegistry registry;
  final BrowserWebViewLifecycleHandler handler;
  final int generation;
  final bool isFull;
  final bool shouldPause;
  final BrowserWebIdentityCoordinator identity;
  final ValueChanged<int> onProgress;
  final ValueChanged<String?> onTitle;
  final ValueChanged<double> onZoomChanged;

  /// Mantiene la sesión al cambiar de layout y recrea solo tras perder renderer.
  @override
  Widget build(BuildContext context) {
    final initialized = registry.isInitialized(tab.id);
    final desktop = identity.usesDesktop(tab.url);
    final prepareInitial = identity.mustPrepareInitial(
      tab.url,
      initialized: initialized,
    );
    return BrowserKeepAliveWrapper(
      child: InAppWebView(
        key: ValueKey('wv_${tab.id}_$generation'),
        keepAlive: registry.keepAliveFor(tab.id),
        // Una WebView conservada ya posee documento: reenviar la URL recargaría
        // formularios, vídeo y posición al alternar entre pila, foco y carrusel.
        initialUrlRequest: initialized || prepareInitial
            ? null
            : URLRequest(url: WebUri(tab.url)),
        initialSettings: BrowserSecurityFirewall.createWebViewSettings(
          isDesktopMode: desktop,
          userAgent: desktop ? BrowserScripts.desktopUserAgent : null,
        ),
        initialUserScripts: UnmodifiableListView<UserScript>([
          if (desktop) BrowserWebIdentityCoordinator.viewportScript,
          UserScript(
            source: BrowserScripts.pinchZoomEngineScript,
            injectionTime: UserScriptInjectionTime.AT_DOCUMENT_END,
          ),
          UserScript(
            source: BrowserScripts.credentialManagerScript,
            injectionTime: UserScriptInjectionTime.AT_DOCUMENT_END,
          ),
          UserScript(
            source: BrowserScripts.audioServiceSyncScript,
            injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
          ),
        ]),
        gestureRecognizers: BrowserGestureArena.buildGestureRecognizers(
          isMaximized: isFull,
          isInteractive: true,
        ),
        onWebViewCreated: (controller) {
          handler.onWebViewCreated(controller);
          shouldPause ? registry.pauseTab(tab.id) : registry.resumeTab(tab.id);
          if (prepareInitial) {
            unawaited(identity.loadInitial(controller, tab.url));
          }
        },
        onZoomScaleChanged: (_, _, scale) => onZoomChanged(scale),
        onLoadStart: handler.onLoadStart,
        onLoadStop: handler.onLoadStop,
        onProgressChanged: (_, progress) => onProgress(progress),
        onTitleChanged: (_, title) => onTitle(title),
        shouldOverrideUrlLoading: handler.navigation.shouldOverrideUrlLoading,
        onReceivedServerTrustAuthRequest: handler.navigation.requestServerTrust,
        onReceivedHttpAuthRequest: handler.navigation.requestHttpAuth,
        onPermissionRequest: handler.navigation.requestPermission,
        onReceivedError: handler.onReceivedError,
        onReceivedHttpError: handler.onReceivedHttpError,
        onUpdateVisitedHistory: handler.onUpdateVisitedHistory,
        onRenderProcessGone: handler.onRenderProcessGone,
      ),
    );
  }
}
