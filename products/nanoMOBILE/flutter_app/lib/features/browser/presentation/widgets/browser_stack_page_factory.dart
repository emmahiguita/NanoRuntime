// QUÉ: construye tarjetas y paneles WebView para la vista de ventanas.
// CÓMO: reutiliza claves y callbacks recibidos sin poseer estado global.
// POR QUÉ: el layout adaptativo queda separado de cada instancia de página.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/browser_tab_notifier.dart';
import '../../application/browser_webview_registry.dart';
import '../../domain/browser_tab_model.dart';
import 'browser_dialog_helper.dart';
import 'single_browser_instance_widget.dart';

final class BrowserStackPageFactory {
  final BrowserTabState tabState;
  final Set<String> minimizedWindowIds;
  final String? maximizedWindowId;
  final bool isDesktopMode, isDarkModeWeb;
  final WidgetRef ref;
  final Key Function(String) instanceKeyForTab;
  final ValueChanged<String> onToggleMinimize, onToggleMaximize, onCloseTab;
  final void Function(String tabId, String url) onNavigate;

  const BrowserStackPageFactory({
    required this.tabState,
    required this.minimizedWindowIds,
    required this.maximizedWindowId,
    required this.isDesktopMode,
    required this.isDarkModeWeb,
    required this.ref,
    required this.instanceKeyForTab,
    required this.onToggleMinimize,
    required this.onToggleMaximize,
    required this.onCloseTab,
    required this.onNavigate,
  });

  Widget pane(
    BuildContext context,
    BrowserTabModel tab, {
    bool isActive = true,
  }) => SingleBrowserInstanceWidget(
    key: instanceKeyForTab(tab.id),
    tab: tab,
    fillHeight: true,
    showCardHeader: true,
    isMinimized: false,
    isMaximized: true,
    isCurrentActive: isActive,
    currentZoom: tab.zoomLevel,
    isDesktopMode: isDesktopMode,
    isDarkModeWeb: isDarkModeWeb,
    onToggleMinimize: () => onToggleMinimize(tab.id),
    onToggleMaximize: () => onToggleMaximize(tab.id),
    onClose: () => onCloseTab(tab.id),
    onNavigate: (url) => onNavigate(tab.id, url),
    onControllerCreated: (controller) => ref
        .read(browserWebViewRegistryProvider)
        .attachController(tab.id, controller),
    onExternalPrompt: (url) =>
        BrowserDialogHelper.promptExternalApp(context, url),
  );

  Widget card(BuildContext context, BrowserTabModel tab, int index) {
    final minimized = minimizedWindowIds.contains(tab.id);
    final maximized = maximizedWindowId == tab.id;
    return SingleBrowserInstanceWidget(
      key: instanceKeyForTab(tab.id),
      tab: tab,
      fillHeight: false,
      showCardHeader: true,
      isMinimized: minimized,
      isMaximized: maximized,
      isCurrentActive: tab.id == tabState.activeTabId,
      currentZoom: tab.zoomLevel,
      isDesktopMode: isDesktopMode,
      isDarkModeWeb: isDarkModeWeb,
      dragIndex: index,
      onToggleMinimize: () => onToggleMinimize(tab.id),
      onToggleMaximize: () => onToggleMaximize(tab.id),
      onSelectTab: () => onToggleMinimize(tab.id),
      onClose: () => onCloseTab(tab.id),
      onControllerCreated: (controller) => ref
          .read(browserWebViewRegistryProvider)
          .attachController(tab.id, controller),
      onNavigate: (url) => onNavigate(tab.id, url),
      onExternalPrompt: (url) =>
          BrowserDialogHelper.promptExternalApp(context, url),
    );
  }
}
