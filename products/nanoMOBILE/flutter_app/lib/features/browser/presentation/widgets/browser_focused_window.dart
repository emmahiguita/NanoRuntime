// QUÉ: Presenta la pestaña activa o carrusel 3D preservando la sesión nativa con InAppWebViewKeepAlive.
// CÓMO: Conecta BrowserWindowTopBar, BrowserWindowTabsStrip y la vista activa respetando la barra universal Nano AI.
// POR QUÉ: Evita doble barra inferior, solapamientos y lienzos en blanco de múltiples PlatformViews Offstage (< 170 líneas).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/widgets/navigation/nano_nav_mode_provider.dart';
import '../../application/browser_tab_notifier.dart';
import '../../application/browser_webview_registry.dart';
import '../../domain/browser_tab_model.dart';
import 'browser_3d_carousel_view.dart';
import 'browser_dialog_helper.dart';
import 'browser_display_mode.dart';
import 'browser_find_in_page_widget.dart';
import 'browser_window_tabs_strip.dart';
import 'browser_window_top_bar.dart';
import 'single_browser_instance_widget.dart';

class BrowserFocusedWindow extends ConsumerWidget {
  final BrowserTabState tabState;
  final BrowserDisplayMode displayMode;
  final bool isEmbedded, isDesktopMode, isDarkModeWeb, showFindInPage;
  final Set<String> minimizedWindowIds;
  final String? maximizedWindowId;
  final GlobalKey Function(String) instanceKeyForTab;
  final VoidCallback? onExit, onToggleDesktopMode;
  final VoidCallback onAddTab, onCloseFindInPage, onOpenOptions;
  final ValueChanged<BrowserDisplayMode> onDisplayMode;
  final ValueChanged<String> onCloseTab, onSelectTab, onSelectFocusedTab;
  final ValueChanged<String> onToggleMinimize, onToggleMaximize;
  final void Function(String tabId, String url) onNavigate;

  const BrowserFocusedWindow({
    super.key,
    required this.tabState,
    required this.displayMode,
    required this.isEmbedded,
    required this.isDesktopMode,
    required this.isDarkModeWeb,
    required this.showFindInPage,
    required this.minimizedWindowIds,
    required this.maximizedWindowId,
    required this.instanceKeyForTab,
    required this.onAddTab,
    required this.onCloseFindInPage,
    required this.onOpenOptions,
    required this.onDisplayMode,
    required this.onCloseTab,
    required this.onSelectTab,
    required this.onSelectFocusedTab,
    required this.onToggleMinimize,
    required this.onToggleMaximize,
    required this.onNavigate,
    this.onExit,
    this.onToggleDesktopMode,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final registry = ref.read(browserWebViewRegistryProvider);
    final navState = ref.watch(nanoNavModeProvider);
    final active = tabState.activeTab;
    final carousel = displayMode == BrowserDisplayMode.carousel3D;
    final radius = isEmbedded ? 16.0 : 0.0;

    // Reserva inferior para que la barra flotante universal Nano AI no tape controles de la web.
    final bottomReserve = isEmbedded || navState.isDrawerMode
        ? 0.0
        : (navState.isMinimizedPill ? 36.0 : 68.0);

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(radius),
        border: isEmbedded
            ? Border.all(color: Theme.of(context).colorScheme.outlineVariant)
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Column(
          children: [
            BrowserWindowTopBar(
              activeTab: active,
              tabCount: tabState.tabs.length,
              displayMode: displayMode,
              controller: registry.controllerFor(active.id),
              onExit: onExit,
              onBack: () => _nav(registry, active, false),
              onForward: () => _nav(registry, active, true),
              onReload: () => registry.controllerFor(active.id)?.reload(),
              onMinimize: () => onToggleMinimize(active.id),
              onMaximize: () => onToggleMaximize(active.id),
              onClose: () => onCloseTab(active.id),
              onOpenOptionsMenu: onOpenOptions,
              onNavigate: (url) => onNavigate(active.id, url),
              onDisplayMode: onDisplayMode,
            ),
            if (!carousel)
              BrowserWindowTabsStrip(
                tabs: tabState.tabs,
                activeTabId: tabState.activeTabId,
                onCloseTab: onCloseTab,
                onAddTab: onAddTab,
                onSelectTab: onSelectFocusedTab,
              ),
            if (showFindInPage)
              BrowserFindInPageWidget(
                controller: registry.controllerFor(active.id),
                onClose: onCloseFindInPage,
              ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: bottomReserve),
                child: carousel
                    ? _carousel(context, ref)
                    : _page(context, ref, active),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _carousel(BuildContext context, WidgetRef ref) => Browser3DCarouselView(
    tabs: tabState.tabs,
    activeTabId: tabState.activeTabId,
    currentZoom: tabState.activeTab.zoomLevel,
    isDesktopMode: isDesktopMode,
    isDarkModeWeb: isDarkModeWeb,
    minimizedWindowIds: minimizedWindowIds,
    maximizedWindowId: maximizedWindowId,
    instanceKeyForTab: instanceKeyForTab,
    onSelectTab: onSelectTab,
    onOpenFocused: () => onDisplayMode(BrowserDisplayMode.focused),
    onCloseTab: onCloseTab,
    onToggleMaximize: onToggleMaximize,
    onToggleMinimize: onToggleMinimize,
    onControllerCreated: (id, c) =>
        ref.read(browserWebViewRegistryProvider).attachController(id, c),
    onNavigate: (input, [id]) => onNavigate(id ?? tabState.activeTabId, input),
    onExternalPrompt: (url) =>
        BrowserDialogHelper.promptExternalApp(context, url),
  );

  Widget _page(BuildContext context, WidgetRef ref, BrowserTabModel tab) =>
      SingleBrowserInstanceWidget(
        key: instanceKeyForTab(tab.id),
        tab: tab,
        fillHeight: true,
        showCardHeader: false,
        isMinimized: false,
        isMaximized: true,
        isCurrentActive: true,
        currentZoom: tab.zoomLevel,
        isDesktopMode: isDesktopMode,
        isDarkModeWeb: isDarkModeWeb,
        onToggleMinimize: () => onToggleMinimize(tab.id),
        onToggleMaximize: () => onToggleMaximize(tab.id),
        onClose: () => onCloseTab(tab.id),
        onControllerCreated: (c) =>
            ref.read(browserWebViewRegistryProvider).attachController(tab.id, c),
        onNavigate: (url) => onNavigate(tab.id, url),
        onExternalPrompt: (url) =>
            BrowserDialogHelper.promptExternalApp(context, url),
      );

  Future<void> _nav(
    BrowserWebViewRegistry r,
    BrowserTabModel t,
    bool forward,
  ) async {
    final c = r.controllerFor(t.id);
    if (c == null) return;
    if (forward ? await c.canGoForward() : await c.canGoBack()) {
      forward ? await c.goForward() : await c.goBack();
    }
  }
}
