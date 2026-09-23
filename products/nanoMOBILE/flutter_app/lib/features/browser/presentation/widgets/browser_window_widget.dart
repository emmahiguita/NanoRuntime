import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nanoai/features/browser/application/browser_history_notifier.dart';
import 'package:nanoai/features/browser/application/browser_tab_notifier.dart';
import 'package:nanoai/features/browser/application/browser_webview_registry.dart';
import 'package:nanoai/features/browser/domain/browser_tab_model.dart';
import 'package:nanoai/features/browser/domain/browser_url_resolver.dart';
import 'package:nanoai/features/browser/presentation/widgets/browser_3d_carousel_view.dart';
import 'package:nanoai/features/browser/presentation/widgets/browser_dialog_helper.dart';
import 'package:nanoai/features/browser/presentation/widgets/browser_find_in_page_widget.dart';
import 'package:nanoai/features/browser/presentation/widgets/browser_menu_action_handler.dart';
import 'package:nanoai/features/browser/presentation/widgets/browser_options_sheet.dart';
import 'package:nanoai/features/browser/presentation/widgets/browser_window_stack_view.dart';
import 'package:nanoai/features/browser/presentation/widgets/browser_window_tabs_strip.dart';
import 'package:nanoai/features/browser/presentation/widgets/browser_window_top_bar.dart';
import 'package:nanoai/features/browser/presentation/widgets/single_browser_instance_widget.dart';

/// Modos de visualización soportados en el Navegador Nano AI
enum BrowserDisplayMode { focused, verticalStack, carousel3D }

/// Coordina pestañas con IndexedStack estable en modo focused para navegación fluida.
/// Al rotar de vertical a horizontal, preserva el audio y la superficie de renderizado nativa.
class BrowserWindowWidget extends ConsumerStatefulWidget {
  final bool isEmbedded;
  final VoidCallback? onFullscreen, onClose;
  final String? initialUrl;
  const BrowserWindowWidget({super.key, this.isEmbedded = false, this.onFullscreen, this.onClose, this.initialUrl});

  @override
  ConsumerState<BrowserWindowWidget> createState() => _BrowserWindowWidgetState();
}

class _BrowserWindowWidgetState extends ConsumerState<BrowserWindowWidget> {
  final Set<String> _minimizedWindowIds = {};
  late final ScrollController _scrollController;
  String? _maximizedWindowId;
  BrowserDisplayMode _displayMode = BrowserDisplayMode.focused;
  bool _isDesktopMode = false, _isDarkModeWeb = false, _showFindInPage = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.initialUrl?.isNotEmpty == true) {
        _onUrlSubmit(widget.initialUrl!);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onUrlSubmit(String input, [String? tabId]) {
    final url = BrowserUrlResolver.resolveUrl(input);
    final activeTab = ref.read(browserTabProvider).activeTab;
    final id = tabId ?? activeTab.id;
    final ctrl = ref.read(browserWebViewRegistryProvider).controllerFor(id);
    if (ctrl != null) { ctrl.loadUrl(urlRequest: URLRequest(url: WebUri(url))); }
    else { ref.read(browserTabProvider.notifier).updateTabById(id, url: url); }
  }

  void _closeTab(String tabId) {
    _minimizedWindowIds.remove(tabId);
    if (_maximizedWindowId == tabId) _maximizedWindowId = null;
    ref.read(browserWebViewRegistryProvider).removeTab(tabId);
    ref.read(browserTabProvider.notifier).closeTab(tabId);
  }

  void _openOptionsMenu(BrowserTabModel tab) {
    final ctrl = ref.read(browserWebViewRegistryProvider).controllerFor(tab.id);
    final handler = BrowserMenuActionHandler(
      context: context, ref: ref, tab: tab, controller: ctrl, currentZoom: tab.zoomLevel,
      isDesktopMode: _isDesktopMode, isDarkModeWeb: _isDarkModeWeb, onNavigate: (u) => _onUrlSubmit(u, tab.id),
      onToggleCarousel: () => setState(() => _displayMode = _displayMode == BrowserDisplayMode.carousel3D ? BrowserDisplayMode.focused : BrowserDisplayMode.carousel3D),
      onZoomChanged: (z) { if (mounted) ref.read(browserTabProvider.notifier).updateTabById(tab.id, zoomLevel: z); },
      onToggleDesktopMode: () => setState(() => _isDesktopMode = !_isDesktopMode),
      onToggleDarkModeWeb: () => setState(() => _isDarkModeWeb = !_isDarkModeWeb),
      onFindInPage: () => setState(() => _showFindInPage = true),
    );
    BrowserOptionsSheet.show(context: context, tab: tab, isBookmarked: ref.read(browserHistoryProvider).isBookmarked(tab.url), isDesktopMode: _isDesktopMode, isDarkModeWeb: _isDarkModeWeb, onAction: handler.handleAction);
  }

  @override
  Widget build(BuildContext context) {
    final tabState = ref.watch(browserTabProvider);
    final notifier = ref.read(browserTabProvider.notifier);
    final activeTab = tabState.activeTab;
    final isLand = MediaQuery.of(context).orientation == Orientation.landscape;
    final activeIdx = tabState.tabs.indexWhere((t) => t.id == tabState.activeTabId).clamp(0, tabState.tabs.isNotEmpty ? tabState.tabs.length - 1 : 0);
    final reg = ref.read(browserWebViewRegistryProvider);

    reg.removeMissing(tabState.tabs.map((t) => t.id).toSet());
    _minimizedWindowIds.removeWhere((id) => !tabState.tabs.any((t) => t.id == id));

    if (_displayMode == BrowserDisplayMode.verticalStack) {
      return BrowserWindowStackView(
        tabState: tabState, minimizedWindowIds: _minimizedWindowIds, maximizedWindowId: _maximizedWindowId,
        currentZoom: activeTab.zoomLevel, isDesktopMode: _isDesktopMode, isDarkModeWeb: _isDarkModeWeb,
        showFindInPage: _showFindInPage, scrollController: _scrollController, ref: ref,
        onToggleAllMinimized: () {
          setState(() {
            final allMin = _minimizedWindowIds.length >= tabState.tabs.length;
            if (allMin) {
              _minimizedWindowIds.clear();
              for (final t in tabState.tabs) { reg.resumeTab(t.id); }
            } else {
              _minimizedWindowIds.addAll(tabState.tabs.map((t) => t.id));
              for (final t in tabState.tabs) { reg.pauseTab(t.id); }
            }
          });
        },
        onAddTab: () => notifier.addTab(), onOpenCarousel: () => setState(() => _displayMode = BrowserDisplayMode.carousel3D),
        onOpenFocused: () => setState(() => _displayMode = BrowserDisplayMode.focused), onOpenOptions: _openOptionsMenu,
        onCloseFindInPage: () => setState(() => _showFindInPage = false), onBackToStack: () => setState(() => _maximizedWindowId = null),
        onToggleMinimize: (id) => setState(() => _minimizedWindowIds.contains(id) ? (_minimizedWindowIds.remove(id), reg.resumeTab(id)) : (_minimizedWindowIds.add(id), reg.pauseTab(id))),
        onToggleMaximize: (id) => setState(() { _maximizedWindowId = _maximizedWindowId == id ? null : id; if (_maximizedWindowId != null) reg.resumeTab(id); }),
        onCloseTab: _closeTab, onNavigate: (id, u) => _onUrlSubmit(u, id),
      );
    }

    final topBar = BrowserWindowTopBar(
      activeTab: activeTab, tabCount: tabState.tabs.length,
      isVerticalStackMode: _displayMode == BrowserDisplayMode.verticalStack, isCarouselMode: _displayMode == BrowserDisplayMode.carousel3D,
      currentZoom: activeTab.zoomLevel, controller: reg.controllerFor(activeTab.id),
      onBack: () async { final c = reg.controllerFor(activeTab.id); if (c != null && await c.canGoBack()) await c.goBack(); },
      onReload: () => reg.controllerFor(activeTab.id)?.reload(),
      onMinimize: () => setState(() { _minimizedWindowIds.add(activeTab.id); reg.pauseTab(activeTab.id); _displayMode = BrowserDisplayMode.verticalStack; }),
      onMaximize: () => setState(() { _maximizedWindowId = activeTab.id; _displayMode = BrowserDisplayMode.verticalStack; }),
      onClose: () => _closeTab(activeTab.id),
      onToggleStackMode: () => setState(() => _displayMode = _displayMode == BrowserDisplayMode.verticalStack ? BrowserDisplayMode.focused : BrowserDisplayMode.verticalStack),
      onToggleCarouselMode: () => setState(() => _displayMode = _displayMode == BrowserDisplayMode.carousel3D ? BrowserDisplayMode.focused : BrowserDisplayMode.carousel3D),
      onOpenOptionsMenu: () => _openOptionsMenu(activeTab),
      onNavigate: (url) => _onUrlSubmit(url, activeTab.id),
      onZoomChanged: (z) { if (mounted) notifier.updateTabById(activeTab.id, zoomLevel: z); },
    );

    final isCarousel = _displayMode == BrowserDisplayMode.carousel3D;
    return Container(
      decoration: BoxDecoration(color: const Color(0xFF030712), borderRadius: BorderRadius.circular(isLand ? 10 : 16), border: Border.all(color: (isCarousel ? const Color(0xFF10B981) : const Color(0xFF059669)).withValues(alpha: 0.5), width: 1.0)),
      child: ClipRRect(borderRadius: BorderRadius.circular(isLand ? 9 : 15), child: Column(children: [
        topBar,
        if (!isCarousel) BrowserWindowTabsStrip(
          tabs: tabState.tabs, activeTabId: tabState.activeTabId, onCloseTab: _closeTab, onAddTab: () => notifier.addTab(),
          onSelectTab: (id) { reg.resumeTab(id); notifier.selectTab(id); if (_displayMode != BrowserDisplayMode.focused) setState(() => _displayMode = BrowserDisplayMode.focused); },
        ),
        if (_showFindInPage) BrowserFindInPageWidget(controller: reg.controllerFor(activeTab.id), onClose: () => setState(() => _showFindInPage = false)),
        Expanded(child: isCarousel
            ? Browser3DCarouselView(
                tabs: tabState.tabs, activeTabId: tabState.activeTabId, currentZoom: activeTab.zoomLevel, isDesktopMode: _isDesktopMode, isDarkModeWeb: _isDarkModeWeb, minimizedWindowIds: _minimizedWindowIds, maximizedWindowId: _maximizedWindowId,
                onSelectTab: (id) { reg.resumeTab(id); _minimizedWindowIds.remove(id); notifier.selectTab(id); }, onOpenFocused: () => setState(() => _displayMode = BrowserDisplayMode.focused),
                onCloseTab: _closeTab, onToggleMaximize: (id) => setState(() => _maximizedWindowId = _maximizedWindowId == id ? null : id),
                onToggleMinimize: (id) => setState(() => _minimizedWindowIds.contains(id) ? _minimizedWindowIds.remove(id) : _minimizedWindowIds.add(id)),
                onControllerCreated: (id, c) => reg.attachController(id, c),
                onNavigate: _onUrlSubmit, onExternalPrompt: (u) => BrowserDialogHelper.promptExternalApp(context, u),
              )
            : IndexedStack(index: activeIdx, children: tabState.tabs.map((tab) => SingleBrowserInstanceWidget(
                key: ValueKey('browser_instance_${tab.id}'), tab: tab, fillHeight: true, showCardHeader: false, isMinimized: false, isMaximized: true,
                currentZoom: activeTab.zoomLevel, isDesktopMode: _isDesktopMode, isDarkModeWeb: _isDarkModeWeb,
                onToggleMinimize: () => setState(() { _minimizedWindowIds.add(tab.id); reg.pauseTab(tab.id); _displayMode = BrowserDisplayMode.verticalStack; }),
                onToggleMaximize: () => setState(() { _maximizedWindowId = tab.id; _displayMode = BrowserDisplayMode.verticalStack; }),
                onClose: () => _closeTab(tab.id), onControllerCreated: (c) => reg.attachController(tab.id, c),
                onNavigate: (u) => _onUrlSubmit(u, tab.id), onExternalPrompt: (u) => BrowserDialogHelper.promptExternalApp(context, u),
              )).toList())),
      ])),
    );
  }
}
