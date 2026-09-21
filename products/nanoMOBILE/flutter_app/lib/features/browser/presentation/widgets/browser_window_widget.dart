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
import 'package:nanoai/features/browser/presentation/widgets/browser_owl_assistant_sheet.dart';
import 'package:nanoai/features/browser/presentation/widgets/browser_window_stack_bar.dart';
import 'package:nanoai/features/browser/presentation/widgets/browser_window_tabs_strip.dart';
import 'package:nanoai/features/browser/presentation/widgets/browser_window_top_bar.dart';
import 'package:nanoai/features/browser/presentation/widgets/single_browser_instance_widget.dart';

/// Modos de visualización soportados en el Navegador Nano AI
enum BrowserDisplayMode { focused, verticalStack, carousel3D }

/// Workspace Multi-Ventana del Navegador Web Real de Nano AI.
/// 
/// - ¿Qué hace?: Coordina múltiples ventanas simultáneas (Google, DeepSeek, ChatGPT, YouTube),
///   soporta vistas Apilada, Carrusel 3D y Enfocada, y previene procesos zombis de WebViews.
/// - ¿Cómo funciona?: Sincroniza las pestañas activas con Riverpod y `BrowserWebViewRegistry`,
///   enrutando cierres, redimensionamientos y acciones a sub-widgets modulares.
/// - ¿Por qué?: Aplica Clean Architecture y SOLID componiendo piezas independientes menores a 200 líneas.
class BrowserWindowWidget extends ConsumerStatefulWidget {
  final bool isEmbedded;
  final VoidCallback? onFullscreen, onClose;
  final String? initialUrl;
  const BrowserWindowWidget({super.key, this.isEmbedded = false, this.onFullscreen, this.onClose, this.initialUrl});

  @override
  ConsumerState<BrowserWindowWidget> createState() => _BrowserWindowWidgetState();
}

class _BrowserWindowWidgetState extends ConsumerState<BrowserWindowWidget> {
  final Map<String, InAppWebViewController> _controllers = {};
  final Set<String> _minimizedWindowIds = {};
  String? _maximizedWindowId;
  BrowserDisplayMode _displayMode = BrowserDisplayMode.verticalStack;
  double _currentZoom = 1.0;
  bool _isDesktopMode = false, _isDarkModeWeb = false, _showFindInPage = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.initialUrl?.isNotEmpty == true) {
        ref.read(browserTabProvider.notifier).updateActiveTab(url: BrowserUrlResolver.resolveUrl(widget.initialUrl!));
      }
      final tabs = ref.read(browserTabProvider).tabs;
      if (tabs.length > 1) setState(() { for (int i = 1; i < tabs.length; i++) { _minimizedWindowIds.add(tabs[i].id); } });
    });
  }

  @override
  void dispose() {
    _controllers.clear();
    super.dispose();
  }

  void _onUrlSubmit(String input) {
    final url = BrowserUrlResolver.resolveUrl(input);
    final activeTab = ref.read(browserTabProvider).activeTab;
    ref.read(browserTabProvider.notifier).updateTabById(activeTab.id, url: url);
    final ctrl = _controllers[activeTab.id] ?? ref.read(browserWebViewRegistryProvider).controllerFor(activeTab.id);
    ctrl?.loadUrl(urlRequest: URLRequest(url: WebUri(url)));
  }

  void _closeTab(String tabId) {
    _controllers.remove(tabId);
    _minimizedWindowIds.remove(tabId);
    if (_maximizedWindowId == tabId) _maximizedWindowId = null;
    ref.read(browserWebViewRegistryProvider).removeTab(tabId);
    ref.read(browserTabProvider.notifier).closeTab(tabId);
  }

  void _openOptionsMenu(BrowserTabModel tab) {
    final ctrl = _controllers[tab.id] ?? ref.read(browserWebViewRegistryProvider).controllerFor(tab.id);
    final handler = BrowserMenuActionHandler(
      context: context, ref: ref, tab: tab, controller: ctrl, currentZoom: _currentZoom,
      isDesktopMode: _isDesktopMode, isDarkModeWeb: _isDarkModeWeb, onNavigate: _onUrlSubmit,
      onToggleCarousel: () => setState(() => _displayMode = _displayMode == BrowserDisplayMode.carousel3D ? BrowserDisplayMode.focused : BrowserDisplayMode.carousel3D),
      onZoomChanged: (z) => setState(() => _currentZoom = z), onToggleDesktopMode: () => setState(() => _isDesktopMode = !_isDesktopMode),
      onToggleDarkModeWeb: () => setState(() => _isDarkModeWeb = !_isDarkModeWeb), onFindInPage: () => setState(() => _showFindInPage = true),
    );
    BrowserOptionsSheet.show(context: context, tab: tab, isBookmarked: ref.read(browserHistoryProvider).isBookmarked(tab.url), isDesktopMode: _isDesktopMode, isDarkModeWeb: _isDarkModeWeb, onAction: handler.handleAction);
  }

  Widget _buildStackItem(BrowserTabModel tab, String activeTabId) {
    final isMin = _minimizedWindowIds.contains(tab.id), isMax = _maximizedWindowId == tab.id;
    return SingleBrowserInstanceWidget(
      key: ValueKey('stack_${tab.id}'), tab: tab, fillHeight: false, showCardHeader: true,
      isMinimized: isMin, isMaximized: isMax, isCurrentActive: tab.id == activeTabId,
      currentZoom: _currentZoom, isDesktopMode: _isDesktopMode, isDarkModeWeb: _isDarkModeWeb,
      onToggleMinimize: () {
        final reg = ref.read(browserWebViewRegistryProvider);
        setState(() => isMin ? (_minimizedWindowIds.remove(tab.id), reg.resumeTab(tab.id)) : (_minimizedWindowIds.add(tab.id), reg.pauseTab(tab.id)));
      },
      onToggleMaximize: () => setState(() => _maximizedWindowId = isMax ? null : tab.id),
      onSelectTab: () => setState(() => isMin ? _minimizedWindowIds.remove(tab.id) : _minimizedWindowIds.add(tab.id)),
      onClose: () => _closeTab(tab.id), onControllerCreated: (c) => _controllers[tab.id] = c,
      onNavigate: _onUrlSubmit, onExternalPrompt: (u) => BrowserDialogHelper.promptExternalApp(context, u),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tabState = ref.watch(browserTabProvider);
    final notifier = ref.read(browserTabProvider.notifier);
    final activeTab = tabState.activeTab;
    final isLand = MediaQuery.of(context).orientation == Orientation.landscape;

    final liveTabIds = tabState.tabs.map((t) => t.id).toSet();
    ref.read(browserWebViewRegistryProvider).removeMissing(liveTabIds);
    _controllers.removeWhere((id, _) => !liveTabIds.contains(id));
    _minimizedWindowIds.removeWhere((id) => !liveTabIds.contains(id));

    if (_displayMode == BrowserDisplayMode.verticalStack) {
      if (_maximizedWindowId != null) {
        final maxTab = tabState.tabs.firstWhere((t) => t.id == _maximizedWindowId, orElse: () => activeTab);
        return Column(children: [
          BrowserWindowMaximizedBar(onBackToStack: () => setState(() => _maximizedWindowId = null), onOpenOptions: () => _openOptionsMenu(maxTab), onAskOwl: () => BrowserOwlAssistantSheet.show(context, tab: maxTab, controller: _controllers[maxTab.id] ?? ref.read(browserWebViewRegistryProvider).controllerFor(maxTab.id))),
          if (_showFindInPage) BrowserFindInPageWidget(controller: _controllers[maxTab.id] ?? ref.read(browserWebViewRegistryProvider).controllerFor(maxTab.id), onClose: () => setState(() => _showFindInPage = false)),
          Expanded(child: SingleBrowserInstanceWidget(
            key: ValueKey('max_${maxTab.id}'), tab: maxTab, fillHeight: true, showCardHeader: true, isMinimized: false, isMaximized: true, isCurrentActive: true,
            currentZoom: _currentZoom, isDesktopMode: _isDesktopMode, isDarkModeWeb: _isDarkModeWeb,
            onToggleMinimize: () => setState(() { _minimizedWindowIds.add(maxTab.id); _maximizedWindowId = null; }),
            onToggleMaximize: () => setState(() => _maximizedWindowId = null), onClose: () => _closeTab(maxTab.id),
            onControllerCreated: (c) => _controllers[maxTab.id] = c, onNavigate: _onUrlSubmit, onExternalPrompt: (u) => BrowserDialogHelper.promptExternalApp(context, u),
          )),
        ]);
      }

      final allMin = _minimizedWindowIds.length >= tabState.tabs.length;
      return Column(children: [
        BrowserWindowStackBar(
          tabCount: tabState.tabs.length, allMinimized: allMin,
          onToggleAllMinimized: () => setState(() => allMin ? _minimizedWindowIds.clear() : _minimizedWindowIds.addAll(tabState.tabs.map((t) => t.id))),
          onAddTab: () => notifier.addTab(), onOpenCarousel: () => setState(() => _displayMode = BrowserDisplayMode.carousel3D),
          onOpenFocused: () => setState(() => _displayMode = BrowserDisplayMode.focused), onOpenOptions: () => _openOptionsMenu(activeTab),
          onAskOwl: () => BrowserOwlAssistantSheet.show(context, tab: activeTab, controller: _controllers[activeTab.id] ?? ref.read(browserWebViewRegistryProvider).controllerFor(activeTab.id)),
        ),
        if (_showFindInPage) BrowserFindInPageWidget(controller: _controllers[activeTab.id] ?? ref.read(browserWebViewRegistryProvider).controllerFor(activeTab.id), onClose: () => setState(() => _showFindInPage = false)),
        Expanded(child: isLand
            ? SingleChildScrollView(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: Column(children: [for (int i = 0; i < tabState.tabs.length; i += 2) _buildStackItem(tabState.tabs[i], tabState.activeTabId)])),
                const SizedBox(width: 6),
                Expanded(child: Column(children: [for (int i = 1; i < tabState.tabs.length; i += 2) _buildStackItem(tabState.tabs[i], tabState.activeTabId)])),
              ]))
            : ListView.builder(padding: const EdgeInsets.only(left: 4, right: 4, top: 2, bottom: 180), physics: const BouncingScrollPhysics(), itemCount: tabState.tabs.length, itemBuilder: (c, i) => _buildStackItem(tabState.tabs[i], tabState.activeTabId))),
      ]);
    }

    final topBar = BrowserWindowTopBar(
      activeTab: activeTab, tabCount: tabState.tabs.length,
      isVerticalStackMode: _displayMode == BrowserDisplayMode.verticalStack, isCarouselMode: _displayMode == BrowserDisplayMode.carousel3D,
      currentZoom: _currentZoom, controller: _controllers[activeTab.id] ?? ref.read(browserWebViewRegistryProvider).controllerFor(activeTab.id),
      onBack: () async { final c = _controllers[activeTab.id] ?? ref.read(browserWebViewRegistryProvider).controllerFor(activeTab.id); if (c != null && await c.canGoBack()) await c.goBack(); },
      onReload: () => (_controllers[activeTab.id] ?? ref.read(browserWebViewRegistryProvider).controllerFor(activeTab.id))?.reload(),
      onToggleStackMode: () => setState(() => _displayMode = _displayMode == BrowserDisplayMode.verticalStack ? BrowserDisplayMode.focused : BrowserDisplayMode.verticalStack), onToggleCarouselMode: () => setState(() => _displayMode = _displayMode == BrowserDisplayMode.carousel3D ? BrowserDisplayMode.focused : BrowserDisplayMode.carousel3D),
      onOpenOptionsMenu: () => _openOptionsMenu(activeTab), onUrlTap: () => BrowserDialogHelper.showUrlEditDialog(context: context, currentUrl: activeTab.url, onSubmitted: _onUrlSubmit),
      onZoomChanged: (z) => setState(() => _currentZoom = z),
    );

    final isCarousel = _displayMode == BrowserDisplayMode.carousel3D;
    final safeIndex = tabState.tabs.indexWhere((t) => t.id == tabState.activeTabId).clamp(0, tabState.tabs.isNotEmpty ? tabState.tabs.length - 1 : 0);

    return Container(
      decoration: BoxDecoration(color: const Color(0xFF030712), borderRadius: BorderRadius.circular(isLand ? 14 : 20), border: Border.all(color: (isCarousel ? const Color(0xFF10B981) : const Color(0xFF059669)).withValues(alpha: 0.5), width: 1.2)),
      child: ClipRRect(borderRadius: BorderRadius.circular(isLand ? 13 : 19), child: Column(children: [
        topBar,
        if (!isCarousel) BrowserWindowTabsStrip(
          tabs: tabState.tabs, activeTabId: tabState.activeTabId, onCloseTab: _closeTab, onAddTab: () => notifier.addTab(),
          onSelectTab: (id) { notifier.selectTab(id); if (_displayMode != BrowserDisplayMode.focused) setState(() => _displayMode = BrowserDisplayMode.focused); },
        ),
        if (_showFindInPage) BrowserFindInPageWidget(controller: _controllers[activeTab.id] ?? ref.read(browserWebViewRegistryProvider).controllerFor(activeTab.id), onClose: () => setState(() => _showFindInPage = false)),
        Expanded(child: isCarousel
            ? Browser3DCarouselView(
                tabs: tabState.tabs, activeTabId: tabState.activeTabId, currentZoom: _currentZoom, isDesktopMode: _isDesktopMode, isDarkModeWeb: _isDarkModeWeb, minimizedWindowIds: _minimizedWindowIds, maximizedWindowId: _maximizedWindowId,
                onSelectTab: (id) { _minimizedWindowIds.remove(id); notifier.selectTab(id); }, onOpenFocused: () => setState(() => _displayMode = BrowserDisplayMode.focused),
                onCloseTab: _closeTab, onToggleMaximize: (id) => setState(() => _maximizedWindowId = _maximizedWindowId == id ? null : id),
                onToggleMinimize: (id) => setState(() => _minimizedWindowIds.contains(id) ? _minimizedWindowIds.remove(id) : _minimizedWindowIds.add(id)),
                onControllerCreated: (id, c) => _controllers[id] = c, onNavigate: _onUrlSubmit, onExternalPrompt: (u) => BrowserDialogHelper.promptExternalApp(context, u),
              )
            : IndexedStack(index: safeIndex, children: tabState.tabs.map((tab) => SingleBrowserInstanceWidget(
                key: ValueKey('win_${tab.id}'), tab: tab, fillHeight: true, showCardHeader: false, isMinimized: false, isMaximized: true,
                currentZoom: _currentZoom, isDesktopMode: _isDesktopMode, isDarkModeWeb: _isDarkModeWeb,
                onToggleMinimize: () => setState(() => _displayMode = BrowserDisplayMode.verticalStack), onToggleMaximize: () => setState(() => _displayMode = BrowserDisplayMode.verticalStack),
                onClose: () => _closeTab(tab.id), onControllerCreated: (c) => _controllers[tab.id] = c, onNavigate: _onUrlSubmit, onExternalPrompt: (u) => BrowserDialogHelper.promptExternalApp(context, u),
              )).toList())),
      ])),
    );
  }
}
