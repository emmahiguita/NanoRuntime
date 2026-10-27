import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nanoai/features/browser/application/browser_tab_notifier.dart';
import 'package:nanoai/features/browser/application/browser_webview_registry.dart';
import 'package:nanoai/features/browser/domain/browser_tab_model.dart';
import 'package:nanoai/features/browser/presentation/widgets/browser_find_in_page_widget.dart';
import 'package:nanoai/features/browser/presentation/widgets/browser_resizable_split.dart';
import 'package:nanoai/features/browser/presentation/widgets/browser_stack_page_factory.dart';
import 'package:nanoai/features/browser/presentation/widgets/browser_window_scroll_rail.dart';
import 'package:nanoai/features/browser/presentation/widgets/browser_window_stack_bar.dart';

/// QUÉ/CÓMO/POR QUÉ: organiza ventanas con claves estables para que rotar,
/// reordenar o dividir la pantalla no destruya las WebViews nativas.
class BrowserWindowStackView extends StatelessWidget {
  final BrowserTabState tabState;
  final Set<String> minimizedWindowIds;
  final String? maximizedWindowId;
  final bool isDesktopMode, isDarkModeWeb, showFindInPage;
  final ScrollController scrollController;
  final WidgetRef ref;
  final Key Function(String tabId) instanceKeyForTab;
  final VoidCallback onToggleAllMinimized,
      onAddTab,
      onOpenCarousel,
      onOpenFocused,
      onCloseFindInPage,
      onBackToStack;
  final VoidCallback? onExit;
  final void Function(BrowserTabModel) onOpenOptions;
  final void Function(String id) onToggleMinimize, onToggleMaximize, onCloseTab;
  final void Function(String tabId, String url) onNavigate;

  const BrowserWindowStackView({
    super.key,
    required this.tabState,
    required this.minimizedWindowIds,
    required this.maximizedWindowId,
    required this.isDesktopMode,
    required this.isDarkModeWeb,
    required this.showFindInPage,
    required this.scrollController,
    required this.ref,
    required this.instanceKeyForTab,
    required this.onToggleAllMinimized,
    required this.onAddTab,
    required this.onOpenCarousel,
    required this.onOpenFocused,
    required this.onCloseFindInPage,
    required this.onBackToStack,
    required this.onOpenOptions,
    required this.onToggleMinimize,
    required this.onToggleMaximize,
    required this.onCloseTab,
    required this.onNavigate,
    this.onExit,
  });

  Widget _find(BrowserWebViewRegistry registry, BrowserTabModel tab) =>
      showFindInPage
      ? BrowserFindInPageWidget(
          controller: registry.controllerFor(tab.id),
          onClose: onCloseFindInPage,
        )
      : const SizedBox.shrink();

  @override
  Widget build(BuildContext context) {
    final reg = ref.read(browserWebViewRegistryProvider);
    final activeTab = tabState.activeTab;
    final isLand = MediaQuery.of(context).orientation == Orientation.landscape;
    final tabs = tabState.tabs;
    final pages = BrowserStackPageFactory(
      tabState: tabState,
      minimizedWindowIds: minimizedWindowIds,
      maximizedWindowId: maximizedWindowId,
      isDesktopMode: isDesktopMode,
      isDarkModeWeb: isDarkModeWeb,
      ref: ref,
      instanceKeyForTab: instanceKeyForTab,
      onToggleMinimize: onToggleMinimize,
      onToggleMaximize: onToggleMaximize,
      onCloseTab: onCloseTab,
      onNavigate: onNavigate,
    );

    if (maximizedWindowId != null) {
      final maxTab = tabs.firstWhere(
        (t) => t.id == maximizedWindowId,
        orElse: () => activeTab,
      );
      return Column(
        children: [
          BrowserWindowMaximizedBar(
            onBackToStack: onBackToStack,
            onOpenOptions: () => onOpenOptions(maxTab),
            onExit: onExit,
          ),
          _find(reg, maxTab),
          Expanded(child: pages.pane(context, maxTab)),
        ],
      );
    }

    final allMin = minimizedWindowIds.length >= tabs.length;
    final activeIdx = tabs
        .indexWhere((t) => t.id == tabState.activeTabId)
        .clamp(0, tabs.isNotEmpty ? tabs.length - 1 : 0);
    final stackBar = BrowserWindowStackBar(
      tabCount: tabs.length,
      allMinimized: allMin,
      onToggleAllMinimized: onToggleAllMinimized,
      onAddTab: onAddTab,
      onOpenCarousel: onOpenCarousel,
      onOpenFocused: onOpenFocused,
      onOpenOptions: () => onOpenOptions(activeTab),
      onExit: onExit,
    );

    if (isLand && tabs.length >= 2) {
      final leftTab = tabs[activeIdx];
      final rightTab = tabs[(activeIdx + 1) % tabs.length];
      return Column(
        children: [
          stackBar,
          _find(reg, activeTab),
          Expanded(
            child: BrowserResizableSplit(
              left: pages.pane(context, leftTab, isActive: true),
              right: pages.pane(context, rightTab, isActive: false),
            ),
          ),
        ],
      );
    }

    if (isLand && tabs.isNotEmpty) {
      return Column(
        children: [
          stackBar,
          _find(reg, activeTab),
          Expanded(child: pages.pane(context, activeTab)),
        ],
      );
    }

    return Column(
      children: [
        stackBar,
        _find(reg, activeTab),
        Expanded(
          child: Stack(
            children: [
              ReorderableListView.builder(
                scrollController: scrollController,
                buildDefaultDragHandles: false,
                padding: const EdgeInsets.only(
                  left: 4,
                  right: 4,
                  top: 2,
                  bottom: 120,
                ),
                physics: const BouncingScrollPhysics(),
                itemCount: tabs.length,
                onReorder: (oldIdx, newIdx) => ref
                    .read(browserTabProvider.notifier)
                    .reorderTab(oldIdx, newIdx),
                itemBuilder: (c, i) => KeyedSubtree(
                  key: ValueKey('tab_item_${tabs[i].id}'),
                  child: pages.card(context, tabs[i], i),
                ),
              ),
              BrowserWindowScrollRail(
                scrollController: scrollController,
                totalWindows: tabs.length,
                activeIndex: activeIdx,
                onJumpToWindow: (idx) {
                  if (scrollController.hasClients) {
                    scrollController.animateTo(
                      (idx * 260.0).clamp(
                        0.0,
                        scrollController.position.maxScrollExtent,
                      ),
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutCubic,
                    );
                  }
                  ref.read(browserTabProvider.notifier).selectTab(tabs[idx].id);
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}
