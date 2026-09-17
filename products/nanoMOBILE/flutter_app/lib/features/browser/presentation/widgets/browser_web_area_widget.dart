import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nanoai/features/browser/application/browser_history_notifier.dart';
import 'package:nanoai/features/browser/application/browser_pip_notifier.dart';
import 'package:nanoai/features/browser/application/browser_tab_notifier.dart';
import 'package:nanoai/features/browser/application/browser_webview_registry.dart';
import 'package:nanoai/features/browser/domain/browser_tab_model.dart';
import 'package:nanoai/features/browser/infrastructure/browser_scripts.dart';
import 'package:nanoai/features/browser/infrastructure/browser_security_firewall.dart';
import 'package:nanoai/features/browser/presentation/widgets/browser_tab_overview.dart';

/// Persistent web surface for all open tabs.
///
/// The native WebViews always remain under the same [IndexedStack]. The tab
/// overview is a screenshot layer placed above them, so changing view modes or
/// selecting another tab never reparents or recreates a platform view.
class BrowserWebAreaWidget extends ConsumerStatefulWidget {
  const BrowserWebAreaWidget({
    super.key,
    required this.controllers,
    required this.currentZoom,
    required this.onExternalPrompt,
    this.is3DOverview = false,
    this.onExitOverview,
  });

  final Map<String, InAppWebViewController> controllers;
  final double currentZoom;
  final bool is3DOverview;
  final VoidCallback? onExitOverview;
  final void Function(String url) onExternalPrompt;

  @override
  ConsumerState<BrowserWebAreaWidget> createState() =>
      _BrowserWebAreaWidgetState();
}

class _BrowserWebAreaWidgetState extends ConsumerState<BrowserWebAreaWidget> {
  final Map<String, Uint8List> _snapshots = {};
  bool _isCapturingOverview = false;

  @override
  void didUpdateWidget(covariant BrowserWebAreaWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.is3DOverview && widget.is3DOverview) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _captureOverview());
    }
  }

  Future<void> _captureOverview() async {
    if (_isCapturingOverview || !mounted) return;
    _isCapturingOverview = true;
    final registry = ref.read(browserWebViewRegistryProvider);
    final tabs = ref.read(browserTabProvider).tabs;

    final results = await Future.wait(
      tabs.map((tab) async {
        final controller =
            registry.controllerFor(tab.id) ?? widget.controllers[tab.id];
        if (controller == null) return MapEntry(tab.id, null);
        try {
          final bytes = await controller.takeScreenshot(
            screenshotConfiguration: ScreenshotConfiguration(
              compressFormat: CompressFormat.JPEG,
              quality: 76,
            ),
          );
          return MapEntry(tab.id, bytes);
        } catch (_) {
          return MapEntry(tab.id, null);
        }
      }),
    );

    if (!mounted) return;
    setState(() {
      for (final result in results) {
        final bytes = result.value;
        if (bytes != null && bytes.isNotEmpty) {
          _snapshots[result.key] = bytes;
        }
      }
      _isCapturingOverview = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final tabState = ref.watch(browserTabProvider);
    final notifier = ref.read(browserTabProvider.notifier);
    final registry = ref.read(browserWebViewRegistryProvider);
    final liveTabIds = tabState.tabs.map((tab) => tab.id).toSet();
    registry.removeMissing(liveTabIds);
    widget.controllers.removeWhere((tabId, _) => !liveTabIds.contains(tabId));
    _snapshots.removeWhere((tabId, _) => !liveTabIds.contains(tabId));

    var activeIndex = tabState.tabs.indexWhere(
      (tab) => tab.id == tabState.activeTabId,
    );
    if (activeIndex < 0) activeIndex = 0;

    final activeController = registry.controllerFor(tabState.activeTabId);
    if (activeController != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref
              .read(browserPipProvider.notifier)
              .attachController(activeController);
        }
      });
    }

    return ColoredBox(
      color: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF070D16)
          : const Color(0xFFF8FAFC),
      child: Stack(
        children: [
          Positioned.fill(
            child: IndexedStack(
              key: const ValueKey('persistent_browser_tab_stack'),
              index: activeIndex,
              sizing: StackFit.expand,
              children: [
                for (final tab in tabState.tabs)
                  _PersistentBrowserTab(
                    key: ValueKey('persistent_webview_${tab.id}'),
                    tab: tab,
                    currentZoom: widget.currentZoom,
                    controllerRegistry: widget.controllers,
                    onExternalPrompt: widget.onExternalPrompt,
                  ),
              ],
            ),
          ),
          if (widget.is3DOverview)
            Positioned.fill(
              child: BrowserTabOverview(
                tabs: tabState.tabs,
                activeIndex: activeIndex,
                snapshots: _snapshots,
                isCapturing: _isCapturingOverview,
                onSelect: (index) {
                  if (index < 0 || index >= tabState.tabs.length) return;
                  notifier.selectTab(tabState.tabs[index].id);
                },
                onOpen: (index) {
                  if (index < 0 || index >= tabState.tabs.length) return;
                  notifier.selectTab(tabState.tabs[index].id);
                  widget.onExitOverview?.call();
                },
                onCloseTab: notifier.closeTab,
                onDone: widget.onExitOverview ?? () {},
              ),
            ),
          if (!widget.is3DOverview && tabState.activeTab.isLoading)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(
                value: tabState.activeTab.progress > 0
                    ? tabState.activeTab.progress
                    : null,
                minHeight: 2,
                backgroundColor: Colors.transparent,
                color: const Color(0xFF3B82F6),
              ),
            ),
        ],
      ),
    );
  }
}

class _PersistentBrowserTab extends ConsumerWidget {
  const _PersistentBrowserTab({
    super.key,
    required this.tab,
    required this.currentZoom,
    required this.controllerRegistry,
    required this.onExternalPrompt,
  });

  final BrowserTabModel tab;
  final double currentZoom;
  final Map<String, InAppWebViewController> controllerRegistry;
  final void Function(String url) onExternalPrompt;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(browserTabProvider.notifier);
    final registry = ref.read(browserWebViewRegistryProvider);
    final alreadyInitialized = registry.isInitialized(tab.id);

    return RepaintBoundary(
      child: InAppWebView(
        key: ValueKey('native_webview_${tab.id}'),
        keepAlive: registry.keepAliveFor(tab.id),
        initialUrlRequest: alreadyInitialized
            ? null
            : URLRequest(url: WebUri(tab.url)),
        initialSettings: BrowserSecurityFirewall.defaultWebViewSettings,
        gestureRecognizers: const <Factory<OneSequenceGestureRecognizer>>{
          Factory<EagerGestureRecognizer>(EagerGestureRecognizer.new),
        },
        onWebViewCreated: (controller) {
          registry.attachController(tab.id, controller);
          controllerRegistry[tab.id] = controller;
        },
        onLoadStart: (_, url) {
          if (url == null) return;
          notifier.updateTabById(
            tab.id,
            url: url.toString(),
            isLoading: true,
            progress: 0.05,
          );
        },
        onLoadStop: (controller, url) async {
          final title = await controller.getTitle();
          final canGoBack = await controller.canGoBack();
          final canGoForward = await controller.canGoForward();
          if (url == null) return;
          final resolvedUrl = url.toString();
          notifier.updateTabById(
            tab.id,
            url: resolvedUrl,
            title: title?.isNotEmpty == true ? title : null,
            isLoading: false,
            progress: 1,
            canGoBack: canGoBack,
            canGoForward: canGoForward,
          );
          ref
              .read(browserHistoryProvider.notifier)
              .recordVisit(resolvedUrl, title ?? '');
          try {
            await controller.evaluateJavascript(
              source: BrowserScripts.mobileViewportAdapterScript,
            );
            if (currentZoom != 1) {
              await controller.evaluateJavascript(
                source: BrowserScripts.setZoomLevelScript(currentZoom),
              );
            }
          } catch (_) {}
        },
        onProgressChanged: (_, progress) {
          notifier.updateTabById(
            tab.id,
            progress: progress / 100,
            isLoading: progress < 100,
          );
        },
        onTitleChanged: (_, title) {
          if (title?.isNotEmpty == true) {
            notifier.updateTabById(tab.id, title: title);
          }
        },
        shouldOverrideUrlLoading: (_, action) async {
          final uri = action.request.url;
          if (uri == null) return NavigationActionPolicy.CANCEL;
          final url = uri.toString();
          if (BrowserSecurityFirewall.isExternalScheme(url)) {
            onExternalPrompt(url);
            return NavigationActionPolicy.CANCEL;
          }
          return BrowserSecurityFirewall.isAllowedUrl(url)
              ? NavigationActionPolicy.ALLOW
              : NavigationActionPolicy.CANCEL;
        },
        onPermissionRequest: (_, request) async {
          debugPrint(
            '[browser:security] permission denied: origin=${request.origin}',
          );
          return PermissionResponse(
            resources: request.resources,
            action: PermissionResponseAction.DENY,
          );
        },
      ),
    );
  }
}
