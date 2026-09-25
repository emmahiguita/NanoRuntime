import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nanoai/features/browser/application/browser_tab_notifier.dart';
import 'package:nanoai/features/browser/application/browser_webview_registry.dart';
import 'package:nanoai/features/browser/domain/browser_tab_model.dart';
import 'package:nanoai/features/browser/presentation/widgets/browser_dialog_helper.dart';
import 'package:nanoai/features/browser/presentation/widgets/browser_find_in_page_widget.dart';
import 'package:nanoai/features/browser/presentation/widgets/browser_window_scroll_rail.dart';
import 'package:nanoai/features/browser/presentation/widgets/browser_window_stack_bar.dart';
import 'package:nanoai/features/browser/presentation/widgets/single_browser_instance_widget.dart';

/// Vista de ventanas múltiples apiladas — con claves estables y soporte adaptativo.
///
/// - QUÉ HACE: Presenta la colección de pestañas en lista reordenable (portrait) o panel split (landscape).
/// - CÓMO FUNCIONA: Mantiene una clave estable [ValueKey] ('browser_instance_${tab.id}') entre orientaciones
///   evitando que Flutter destruya la PlatformView nativa del WebView al rotar de vertical a horizontal.
/// - POR QUÉ: Elimina la pérdida de sonido y pantallas negras por reconstrucción destructiva (<200 líneas).
class BrowserWindowStackView extends StatelessWidget {
  final BrowserTabState tabState;
  final Set<String> minimizedWindowIds;
  final String? maximizedWindowId;
  final double currentZoom;
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
  final void Function(BrowserTabModel) onOpenOptions;
  final void Function(String id) onToggleMinimize, onToggleMaximize, onCloseTab;
  final void Function(String tabId, String url) onNavigate;

  const BrowserWindowStackView({
    super.key,
    required this.tabState,
    required this.minimizedWindowIds,
    required this.maximizedWindowId,
    required this.currentZoom,
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
  });

  Widget _buildPane(
    BuildContext context,
    BrowserTabModel tab, {
    bool isActive = true,
  }) {
    return SingleBrowserInstanceWidget(
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
      onControllerCreated: (c) =>
          ref.read(browserWebViewRegistryProvider).attachController(tab.id, c),
      onExternalPrompt: (u) =>
          BrowserDialogHelper.promptExternalApp(context, u),
    );
  }

  Widget _buildItem(BuildContext context, BrowserTabModel tab, {int? index}) {
    final isMin = minimizedWindowIds.contains(tab.id);
    final isMax = maximizedWindowId == tab.id;
    return SingleBrowserInstanceWidget(
      key: instanceKeyForTab(tab.id),
      tab: tab,
      fillHeight: false,
      showCardHeader: true,
      isMinimized: isMin,
      isMaximized: isMax,
      isCurrentActive: tab.id == tabState.activeTabId,
      currentZoom: tab.zoomLevel,
      isDesktopMode: isDesktopMode,
      isDarkModeWeb: isDarkModeWeb,
      dragIndex: index,
      onToggleMinimize: () => onToggleMinimize(tab.id),
      onToggleMaximize: () => onToggleMaximize(tab.id),
      onSelectTab: () => onToggleMinimize(tab.id),
      onClose: () => onCloseTab(tab.id),
      onControllerCreated: (c) =>
          ref.read(browserWebViewRegistryProvider).attachController(tab.id, c),
      onNavigate: (url) => onNavigate(tab.id, url),
      onExternalPrompt: (u) =>
          BrowserDialogHelper.promptExternalApp(context, u),
    );
  }

  @override
  Widget build(BuildContext context) {
    final reg = ref.read(browserWebViewRegistryProvider);
    final activeTab = tabState.activeTab;
    final isLand = MediaQuery.of(context).orientation == Orientation.landscape;
    final tabs = tabState.tabs;

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
          ),
          if (showFindInPage)
            BrowserFindInPageWidget(
              controller: reg.controllerFor(maxTab.id),
              onClose: onCloseFindInPage,
            ),
          Expanded(
            child: SingleBrowserInstanceWidget(
              key: instanceKeyForTab(maxTab.id),
              tab: maxTab,
              fillHeight: true,
              showCardHeader: true,
              isMinimized: false,
              isMaximized: true,
              isCurrentActive: true,
              currentZoom: maxTab.zoomLevel,
              isDesktopMode: isDesktopMode,
              isDarkModeWeb: isDarkModeWeb,
              onToggleMinimize: () => onToggleMinimize(maxTab.id),
              onToggleMaximize: onBackToStack,
              onClose: () => onCloseTab(maxTab.id),
              onNavigate: (url) => onNavigate(maxTab.id, url),
              onControllerCreated: (c) => reg.attachController(maxTab.id, c),
              onExternalPrompt: (u) =>
                  BrowserDialogHelper.promptExternalApp(context, u),
            ),
          ),
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
    );

    if (isLand && tabs.length >= 2) {
      final leftTab = tabs[activeIdx];
      final rightTab = tabs[(activeIdx + 1) % tabs.length];
      return Column(
        children: [
          stackBar,
          if (showFindInPage)
            BrowserFindInPageWidget(
              controller: reg.controllerFor(activeTab.id),
              onClose: onCloseFindInPage,
            ),
          Expanded(
            child: _ResizableLandscapeSplit(
              left: _buildPane(context, leftTab, isActive: true),
              right: _buildPane(context, rightTab, isActive: false),
            ),
          ),
        ],
      );
    }

    if (isLand && tabs.isNotEmpty) {
      return Column(
        children: [
          stackBar,
          if (showFindInPage)
            BrowserFindInPageWidget(
              controller: reg.controllerFor(activeTab.id),
              onClose: onCloseFindInPage,
            ),
          Expanded(child: _buildPane(context, activeTab)),
        ],
      );
    }

    return Column(
      children: [
        stackBar,
        if (showFindInPage)
          BrowserFindInPageWidget(
            controller: reg.controllerFor(activeTab.id),
            onClose: onCloseFindInPage,
          ),
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
                  child: _buildItem(context, tabs[i], index: i),
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

/// Split horizontal ajustable. Mantiene ambas WebViews montadas mientras el
/// usuario cambia el ancho; arrastrar el separador no recrea ninguna página.
class _ResizableLandscapeSplit extends StatefulWidget {
  const _ResizableLandscapeSplit({required this.left, required this.right});

  final Widget left;
  final Widget right;

  @override
  State<_ResizableLandscapeSplit> createState() =>
      _ResizableLandscapeSplitState();
}

class _ResizableLandscapeSplitState extends State<_ResizableLandscapeSplit> {
  static const double _dividerWidth = 18;
  double _leftFraction = 0.5;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final available = (constraints.maxWidth - _dividerWidth).clamp(
        1.0,
        double.infinity,
      );
      return Row(
        children: [
          SizedBox(width: available * _leftFraction, child: widget.left),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onDoubleTap: () => setState(() => _leftFraction = 0.5),
            onHorizontalDragUpdate: (details) => setState(() {
              _leftFraction = (_leftFraction + details.delta.dx / available)
                  .clamp(0.22, 0.78);
            }),
            child: const SizedBox(
              width: _dividerWidth,
              child: Center(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Color(0xFF334155),
                    borderRadius: BorderRadius.all(Radius.circular(2)),
                  ),
                  child: SizedBox(width: 3, height: 42),
                ),
              ),
            ),
          ),
          Expanded(child: widget.right),
        ],
      );
    },
  );
}
