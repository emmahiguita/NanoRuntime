import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nanoai/features/browser/application/browser_history_notifier.dart';
import 'package:nanoai/features/browser/application/browser_pip_notifier.dart';
import 'package:nanoai/features/browser/application/browser_tab_notifier.dart';
import 'package:nanoai/features/browser/domain/browser_tab_model.dart';
import 'package:nanoai/features/browser/application/browser_webview_registry.dart';
import 'package:nanoai/features/browser/infrastructure/browser_scripts.dart';
import 'package:nanoai/features/browser/infrastructure/browser_security_firewall.dart';
import 'package:nanoai/features/browser/presentation/widgets/browser_dialog_helper.dart';
import 'package:nanoai/features/browser/presentation/widgets/browser_tab_bar_widget.dart';

/// Tarjeta de Ventana del Navegador Web Real con diseño profesional exacto
/// al mockup del usuario (cabecera con favicon, título, URL con punto azul,
/// botones de ventana [ — ] [ ▢ ] [ ✕ ] y WebView en vivo sin recargas).
class SingleBrowserInstanceWidget extends ConsumerStatefulWidget {
  final BrowserTabModel tab;
  final bool isMaximized;
  final bool isMinimized;
  final bool isCurrentActive;
  final double currentZoom;
  final bool isDesktopMode;
  final bool isDarkModeWeb;
  final VoidCallback onToggleMinimize;
  final VoidCallback onToggleMaximize;
  final VoidCallback onClose;
  final bool fillHeight;
  final bool showCardHeader;
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
  ConsumerState<SingleBrowserInstanceWidget> createState() =>
      _SingleBrowserInstanceWidgetState();
}

class _SingleBrowserInstanceWidgetState
    extends ConsumerState<SingleBrowserInstanceWidget>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  void didUpdateWidget(covariant SingleBrowserInstanceWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final ctrl = ref.read(browserWebViewRegistryProvider).controllerFor(widget.tab.id);
    if (widget.tab.url != oldWidget.tab.url) {
      ctrl?.loadUrl(urlRequest: URLRequest(url: WebUri(widget.tab.url)));
    }
    if (widget.currentZoom != oldWidget.currentZoom) {
      ctrl?.evaluateJavascript(source: BrowserScripts.setZoomLevelScript(widget.currentZoom));
    }
    if (widget.isDarkModeWeb != oldWidget.isDarkModeWeb) {
      ctrl?.evaluateJavascript(source: BrowserScripts.toggleDarkModeWebScript);
    }
    if (widget.isDesktopMode != oldWidget.isDesktopMode && ctrl != null) {
      _baselineScale = 0.0;
      ctrl.setSettings(
        settings: InAppWebViewSettings(
          userAgent: widget.isDesktopMode ? BrowserScripts.desktopUserAgent : "",
          preferredContentMode: widget.isDesktopMode ? UserPreferredContentMode.DESKTOP : UserPreferredContentMode.MOBILE,
          useWideViewPort: true,
          loadWithOverviewMode: true,
        ),
      );
      ctrl.evaluateJavascript(
        source: widget.isDesktopMode
            ? BrowserScripts.desktopViewportAdapterScript
            : BrowserScripts.mobileViewportAdapterScript,
      );
      ctrl.reload();
    }
  }

  double _baselineScale = 0.0;
  Timer? _zoomBadgeTimer;
  double _currentScale = 1.0;
  bool _showZoomBadge = false;

  @override
  void dispose() {
    _zoomBadgeTimer?.cancel();
    super.dispose();
  }

  void _triggerTransientZoomBadge(double scale) {
    _zoomBadgeTimer?.cancel();
    if (mounted) {
      setState(() {
        _currentScale = scale;
        _showZoomBadge = true;
      });
    }
    _zoomBadgeTimer = Timer(const Duration(milliseconds: 1300), () {
      if (mounted) {
        setState(() {
          _showZoomBadge = false;
        });
      }
    });
  }

  double _userHeight = 110.0;

  Color _getSiteColor(String url) {
    final lower = url.toLowerCase();
    if (lower.contains('deepseek') || lower.contains('deeksepp')) {
      return const Color(0xFF8B5CF6);
    }
    if (lower.contains('chatgpt') || lower.contains('openai')) {
      return const Color(0xFF10A37F);
    }
    if (lower.contains('youtube')) {
      return const Color(0xFFEF4444);
    }
    if (lower.contains('facebook') || lower.contains('fb.com')) {
      return const Color(0xFF1877F2);
    }
    if (lower.contains('github')) {
      return const Color(0xFF8B949E);
    }
    return const Color(0xFF2563EB); // Google / default electric blue
  }

  Widget _buildFavicon(String url, Color siteColor) {
    final lower = url.toLowerCase();
    if (lower.contains('google')) {
      return Container(
        width: 20, height: 20,
        decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
        alignment: Alignment.center,
        child: const Text('G', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF4285F4))),
      );
    }
    if (lower.contains('deepseek') || lower.contains('deeksepp')) {
      return Container(
        width: 20, height: 20,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(4), color: const Color(0xFF7C3AED)),
        alignment: Alignment.center,
        child: const Text('D', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
      );
    }
    if (lower.contains('chatgpt') || lower.contains('openai')) {
      return Container(
        width: 20, height: 20,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(4), color: const Color(0xFF10A37F)),
        alignment: Alignment.center,
        child: const Icon(Icons.smart_toy_rounded, size: 12, color: Colors.white),
      );
    }
    return Container(
      width: 20, height: 20,
      decoration: BoxDecoration(shape: BoxShape.circle, color: siteColor.withValues(alpha: 0.2)),
      alignment: Alignment.center,
      child: Icon(BrowserTabBarWidget.getBrandIcon(url), size: 12, color: siteColor),
    );
  }

  Widget _buildWebViewStack(Color siteColor, BrowserTabNotifier notifier) {
    final registry = ref.read(browserWebViewRegistryProvider);

    return Stack(
      children: [
        _KeepAliveWrapper(
          child: InAppWebView(
            key: ValueKey('wv_${widget.tab.id}'),
            keepAlive: registry.keepAliveFor(widget.tab.id),
            initialUrlRequest: URLRequest(url: WebUri(widget.tab.url)),
            initialSettings: InAppWebViewSettings(
              useShouldOverrideUrlLoading: true,
              mediaPlaybackRequiresUserGesture: false,
              allowsInlineMediaPlayback: true,
              allowFileAccessFromFileURLs: false,
              allowUniversalAccessFromFileURLs: false,
              javaScriptEnabled: true,
              javaScriptCanOpenWindowsAutomatically: false,
              supportMultipleWindows: false,
              supportZoom: true,
              builtInZoomControls: true,
              displayZoomControls: false,
              useWideViewPort: true,
              loadWithOverviewMode: true,
              useHybridComposition: true,
              domStorageEnabled: true,
              databaseEnabled: true,
              transparentBackground: false,
              safeBrowsingEnabled: true,
              mixedContentMode: MixedContentMode.MIXED_CONTENT_COMPATIBILITY_MODE,
              cacheEnabled: true,
              cacheMode: CacheMode.LOAD_DEFAULT,
              hardwareAcceleration: true,
              loadsImagesAutomatically: true,
              blockNetworkImage: false,
              offscreenPreRaster: true,
              overScrollMode: OverScrollMode.IF_CONTENT_SCROLLS,
              networkAvailable: true,
              userAgent: widget.isDesktopMode ? BrowserScripts.desktopUserAgent : "",
              preferredContentMode: widget.isDesktopMode
                  ? UserPreferredContentMode.DESKTOP
                  : UserPreferredContentMode.MOBILE,
            ),
            initialUserScripts: UnmodifiableListView<UserScript>([
              UserScript(
                source: widget.isDesktopMode
                    ? BrowserScripts.desktopViewportAdapterScript
                    : BrowserScripts.mobileViewportAdapterScript,
                injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
              ),
              UserScript(
                source: BrowserScripts.pinchZoomEngineScript,
                injectionTime: UserScriptInjectionTime.AT_DOCUMENT_END,
              ),
            ]),
            gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
              Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer()),
            },
            onWebViewCreated: (ctrl) {
              registry.attachController(widget.tab.id, ctrl);
              widget.onControllerCreated?.call(ctrl);
              ctrl.addJavaScriptHandler(
                handlerName: 'nanoZoomUpdate',
                callback: (args) {
                  if (args.isNotEmpty && args[0] is num) {
                    final zoom = (args[0] as num).toDouble();
                    _triggerTransientZoomBadge(zoom);
                    notifier.updateTabById(widget.tab.id, zoomLevel: zoom);
                  }
                },
              );
            },
            onZoomScaleChanged: (ctrl, oldScale, newScale) {
              final dpr = MediaQuery.maybeOf(context)?.devicePixelRatio ?? 2.75;
              if (_baselineScale <= 0.0) {
                _baselineScale = dpr > 0.0 ? dpr : (newScale > 1.0 ? newScale : 1.0);
              }
              final normalizedScale = _baselineScale > 0 ? (newScale / _baselineScale) : newScale;
              _triggerTransientZoomBadge(normalizedScale);
              notifier.updateTabById(widget.tab.id, zoomLevel: normalizedScale);
            },
            onLoadStart: (ctrl, url) {
              if (url != null) {
                notifier.updateTabById(
                  widget.tab.id,
                  url: url.toString(),
                  isLoading: true,
                  progress: 0.1,
                );
              }
            },
            onLoadStop: (ctrl, url) async {
              final title = await ctrl.getTitle();
              final canBack = await ctrl.canGoBack();
              final canFwd = await ctrl.canGoForward();
              if (url != null) {
                notifier.updateTabById(
                  widget.tab.id,
                  url: url.toString(),
                  title: title?.isNotEmpty == true ? title : null,
                  isLoading: false,
                  progress: 1.0,
                  canGoBack: canBack,
                  canGoForward: canFwd,
                );
                ref.read(browserHistoryProvider.notifier).recordVisit(
                  url.toString(),
                  title ?? '',
                );
              }
              try {
                await ctrl.evaluateJavascript(
                  source: widget.isDesktopMode
                      ? BrowserScripts.desktopViewportAdapterScript
                      : BrowserScripts.mobileViewportAdapterScript,
                );
                await ctrl.evaluateJavascript(
                  source: BrowserScripts.pinchZoomEngineScript,
                );
                final effectiveZoom = widget.tab.zoomLevel != 1.0
                    ? widget.tab.zoomLevel
                    : widget.currentZoom;
                if (effectiveZoom != 1.0) {
                  await ctrl.evaluateJavascript(
                    source: BrowserScripts.setZoomLevelScript(effectiveZoom),
                  );
                }
                if (widget.isDarkModeWeb) {
                  await ctrl.evaluateJavascript(
                    source: BrowserScripts.toggleDarkModeWebScript,
                  );
                }
              } catch (_) {}
              ref.read(browserPipProvider.notifier).attachController(ctrl);
            },
            onProgressChanged: (ctrl, progress) {
              notifier.updateTabById(
                widget.tab.id,
                progress: progress / 100.0,
                isLoading: progress < 100,
              );
            },
            onTitleChanged: (ctrl, title) {
              if (title?.isNotEmpty == true) {
                notifier.updateTabById(widget.tab.id, title: title);
              }
            },
            shouldOverrideUrlLoading: (ctrl, navAction) async {
              final uri = navAction.request.url?.uriValue;
              if (uri == null) return NavigationActionPolicy.ALLOW;
              if (BrowserSecurityFirewall.isExternalScheme(uri.toString())) {
                widget.onExternalPrompt?.call(uri.toString());
                return NavigationActionPolicy.CANCEL;
              }
              return NavigationActionPolicy.ALLOW;
            },
          ),
        ),
        if (widget.tab.isLoading && widget.tab.progress < 1.0)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LinearProgressIndicator(
              value: widget.tab.progress,
              minHeight: 2.5,
              backgroundColor: Colors.transparent,
              valueColor: AlwaysStoppedAnimation<Color>(siteColor),
            ),
          ),
        if (_showZoomBadge)
          Positioned(
            top: 12,
            right: 12,
            child: IgnorePointer(
              child: AnimatedOpacity(
                opacity: _showZoomBadge ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 180),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xEB091424),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: siteColor.withValues(alpha: 0.6),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.zoom_in_rounded, size: 14, color: siteColor),
                      const SizedBox(width: 5),
                      Text(
                        '${(_currentScale * 100).round()}%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final siteColor = _getSiteColor(widget.tab.url);
    final notifier = ref.read(browserTabProvider.notifier);
    final mq = MediaQuery.of(context);
    final isLandscape = mq.orientation == Orientation.landscape;
    final screenHeight = mq.size.height;

    // Si no se requiere la cabecera de tarjeta (vista limpia directa de la página web)
    if (!widget.showCardHeader) {
      return _buildWebViewStack(siteColor, notifier);
    }

    final maxLandscapeH = (screenHeight - 110.0).clamp(160.0, 300.0);
    final rawH = widget.isMaximized
        ? (isLandscape ? maxLandscapeH : 560.0)
        : (isLandscape
            ? _userHeight.clamp(28.0, maxLandscapeH)
            : _userHeight.clamp(36.0, 820.0));
    final effectiveHeight = rawH.roundToDouble();

    // Modo tarjeta con controles de ventana (para el carrusel / vista multi-ventana)
    final isActive = widget.isCurrentActive;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      margin: EdgeInsets.only(bottom: isLandscape ? 4 : 6),
      decoration: BoxDecoration(
        color: const Color(0xF2071220),
        borderRadius: BorderRadius.circular(isLandscape ? 11 : 14),
        border: Border.all(
          color: isActive ? siteColor : siteColor.withValues(alpha: 0.5),
          width: isActive ? (isLandscape ? 1.4 : 1.8) : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: siteColor.withValues(alpha: isActive ? 0.30 : 0.12),
            blurRadius: isActive ? (isLandscape ? 8 : 14) : 8,
            spreadRadius: isActive ? 0 : -2,
            offset: const Offset(0, 2),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(isLandscape ? 10 : 13),
        child: Column(
          mainAxisSize: widget.fillHeight ? MainAxisSize.max : MainAxisSize.min,
          children: [
            // Barra de título de la ventana
            Container(
              height: isLandscape ? 24 : 38,
              padding: EdgeInsets.symmetric(horizontal: isLandscape ? 4 : 8),
              color: const Color(0xFF0B1728),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        if (widget.onNavigate != null) {
                          BrowserDialogHelper.showUrlEditDialog(
                            context: context,
                            currentUrl: widget.tab.url,
                            onSubmitted: widget.onNavigate!,
                          );
                        } else {
                          widget.onSelectTab?.call();
                        }
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: Row(
                          children: [
                            _buildFavicon(widget.tab.url, siteColor),
                            SizedBox(width: isLandscape ? 5 : 8),
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.tab.title.isNotEmpty ? widget.tab.title : 'Navegador',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: isLandscape ? 10.5 : 11.5,
                                      height: 1.15,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  if (!isLandscape || screenHeight > 340) ...[
                                    const SizedBox(height: 1),
                                    Row(
                                      children: [
                                        Container(
                                          width: 3.5,
                                          height: 3.5,
                                          decoration: BoxDecoration(shape: BoxShape.circle, color: siteColor),
                                        ),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            widget.tab.url,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: isLandscape ? 8.5 : 9.5,
                                              height: 1.15,
                                              color: const Color(0xFF94A3B8),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: isLandscape ? 2 : 4),
                  _WindowButton(
                    icon: Icons.refresh_rounded,
                    size: isLandscape ? 11 : 13,
                    onTap: () {
                      final ctrl = ref.read(browserWebViewRegistryProvider).controllerFor(widget.tab.id);
                      ctrl?.reload();
                    },
                  ),
                  SizedBox(width: isLandscape ? 2 : 4),
                  _WindowButton(
                    icon: widget.isMinimized ? Icons.keyboard_arrow_down_rounded : Icons.remove_rounded,
                    size: isLandscape ? 11 : 13,
                    onTap: widget.onToggleMinimize,
                  ),
                  SizedBox(width: isLandscape ? 2 : 4),
                  _WindowButton(
                    icon: widget.isMaximized ? Icons.filter_none_rounded : Icons.check_box_outline_blank_rounded,
                    size: isLandscape ? 10 : 12,
                    onTap: widget.onToggleMaximize,
                  ),
                  SizedBox(width: isLandscape ? 2 : 4),
                  _WindowButton(
                    icon: Icons.close_rounded,
                    size: isLandscape ? 11 : 13,
                    onTap: widget.onClose,
                  ),
                ],
              ),
            ),

            if (!widget.isMinimized) ...[
              widget.fillHeight
                  ? Expanded(child: _buildWebViewStack(siteColor, notifier))
                  : SizedBox(
                      height: effectiveHeight,
                      child: _buildWebViewStack(siteColor, notifier),
                    ),
              // Tirador táctil inferior para estirar y reducir la ventana al tamaño deseado
              if (!widget.fillHeight)
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onDoubleTap: () {
                    HapticFeedback.mediumImpact();
                    setState(() {
                      _userHeight = _userHeight <= 45.0 ? 150.0 : 36.0;
                    });
                  },
                  onVerticalDragUpdate: (details) {
                    final minH = isLandscape ? 28.0 : 36.0;
                    final maxH = isLandscape ? maxLandscapeH : 820.0;
                    setState(() {
                      _userHeight = ((_userHeight + details.delta.dy).clamp(minH, maxH)).roundToDouble();
                    });
                  },
                  child: Container(
                    height: isLandscape ? 9 : 14,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0B1728),
                      border: Border(
                        top: BorderSide(
                          color: siteColor.withValues(alpha: 0.25),
                          width: 0.8,
                        ),
                      ),
                    ),
                    child: Container(
                      width: isLandscape ? 24 : 34,
                      height: isLandscape ? 2 : 3,
                      decoration: BoxDecoration(
                        color: siteColor.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(2),
                        boxShadow: [
                          BoxShadow(
                            color: siteColor.withValues(alpha: 0.35),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _WindowButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final double size;

  const _WindowButton({
    required this.icon,
    required this.onTap,
    this.size = 14,
  });

  @override
  Widget build(BuildContext context) {
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    final btnSize = isLandscape ? 17.0 : 22.0;
    final iconSize = isLandscape ? (size > 11 ? 10.0 : size - 1.5) : size;

    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      borderRadius: BorderRadius.circular(3),
      child: Container(
        width: btnSize,
        height: btnSize,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Icon(icon, size: iconSize, color: const Color(0xFFCBD5E1)),
      ),
    );
  }
}

class _KeepAliveWrapper extends StatefulWidget {
  final Widget child;
  const _KeepAliveWrapper({required this.child});

  @override
  State<_KeepAliveWrapper> createState() => _KeepAliveWrapperState();
}

class _KeepAliveWrapperState extends State<_KeepAliveWrapper>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
