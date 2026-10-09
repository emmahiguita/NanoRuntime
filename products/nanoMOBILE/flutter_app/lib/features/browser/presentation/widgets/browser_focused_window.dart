// QUÉ: presenta página activa o carrusel sin recrear las WebViews existentes.
// CÓMO: conserva claves por pestaña y coordina barra, pestañas y contenido.
// POR QUÉ: separa el layout visual del estado y ciclo de vida del navegador.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  final VoidCallback? onExit;
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
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final registry = ref.read(browserWebViewRegistryProvider);
    final active = tabState.activeTab;
    final carousel = displayMode == BrowserDisplayMode.carousel3D;
    final radius = isEmbedded ? 16.0 : 0.0;
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
              onBack: () => _goBack(registry, active),
              onForward: () => _goForward(registry, active),
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
              child: carousel
                  ? _carousel(context, ref)
                  // El keep-alive conserva cada sesión; montar solo la activa
                  // evita cinco PlatformViews, timers y páginas en paralelo.
                  : _page(context, ref, active),
            ),
          ],
        ),
      ),
    );
  }

  Widget _carousel(BuildContext context, WidgetRef ref) =>
      Browser3DCarouselView(
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
        onControllerCreated: (id, controller) => ref
            .read(browserWebViewRegistryProvider)
            .attachController(id, controller),
        onNavigate: (input, [id]) =>
            onNavigate(id ?? tabState.activeTabId, input),
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
        isCurrentActive: tab.id == tabState.activeTabId,
        currentZoom: tab.zoomLevel,
        isDesktopMode: isDesktopMode,
        isDarkModeWeb: isDarkModeWeb,
        onToggleMinimize: () => onToggleMinimize(tab.id),
        onToggleMaximize: () => onToggleMaximize(tab.id),
        onClose: () => onCloseTab(tab.id),
        onControllerCreated: (controller) => ref
            .read(browserWebViewRegistryProvider)
            .attachController(tab.id, controller),
        onNavigate: (url) => onNavigate(tab.id, url),
        onExternalPrompt: (url) =>
            BrowserDialogHelper.promptExternalApp(context, url),
      );

  Future<void> _goBack(
    BrowserWebViewRegistry registry,
    BrowserTabModel tab,
  ) async {
    final controller = registry.controllerFor(tab.id);
    if (controller != null && await controller.canGoBack()) {
      await controller.goBack();
    }
  }

  Future<void> _goForward(
    BrowserWebViewRegistry registry,
    BrowserTabModel tab,
  ) async {
    final controller = registry.controllerFor(tab.id);
    if (controller != null && await controller.canGoForward()) {
      await controller.goForward();
    }
  }
}
