// QUÉ: Visor de pestañas en carrusel animado estilo CoverFlow / iOS Safari.
// CÓMO: PageView con escala suave y tarjetas que exponen preview, cabecera y cierre [X].
// POR QUÉ: Permite alternar y elegir pestañas de forma visual sin cabeceras duplicadas (< 180 líneas).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../../domain/browser_tab_model.dart';
import 'browser_3d_carousel_page.dart';
import 'browser_carousel_card.dart';
import 'single_browser_instance_widget.dart';

class Browser3DCarouselView extends StatefulWidget {
  final List<BrowserTabModel> tabs;
  final String activeTabId;
  final ValueChanged<String> onSelectTab;
  final VoidCallback onOpenFocused;
  final ValueChanged<String> onCloseTab, onToggleMaximize, onToggleMinimize;
  final Set<String> minimizedWindowIds;
  final String? maximizedWindowId;
  final double currentZoom;
  final bool isDesktopMode, isDarkModeWeb;
  final Key Function(String tabId) instanceKeyForTab;
  final void Function(String tabId, InAppWebViewController ctrl)? onControllerCreated;
  final ValueChanged<String>? onNavigate;
  final void Function(String url)? onExternalPrompt;

  const Browser3DCarouselView({
    super.key,
    required this.tabs,
    required this.activeTabId,
    required this.onSelectTab,
    required this.onOpenFocused,
    required this.onCloseTab,
    required this.onToggleMaximize,
    required this.onToggleMinimize,
    required this.minimizedWindowIds,
    this.maximizedWindowId,
    required this.instanceKeyForTab,
    this.currentZoom = 1.0,
    this.isDesktopMode = false,
    this.isDarkModeWeb = false,
    this.onControllerCreated,
    this.onNavigate,
    this.onExternalPrompt,
  });

  @override
  State<Browser3DCarouselView> createState() => _Browser3DCarouselViewState();
}

class _Browser3DCarouselViewState extends State<Browser3DCarouselView> {
  late final PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    final idx = widget.tabs.indexWhere((t) => t.id == widget.activeTabId);
    _currentPage = idx >= 0 ? idx : 0;
    _pageController = PageController(
      initialPage: _currentPage,
      viewportFraction: 0.84,
    );
  }

  @override
  void didUpdateWidget(covariant Browser3DCarouselView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.activeTabId != oldWidget.activeTabId) {
      final idx = widget.tabs.indexWhere((t) => t.id == widget.activeTabId);
      if (idx >= 0 && idx != _currentPage && _pageController.hasClients) {
        _currentPage = idx;
        _pageController.animateToPage(
          idx,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        );
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isLand = MediaQuery.of(context).orientation == Orientation.landscape;

    if (widget.tabs.isEmpty) {
      return const Center(
        child: Text(
          'No hay pestañas abiertas',
          style: TextStyle(color: Color(0xFF94A3B8)),
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: PageView.builder(
            key: const PageStorageKey<String>('browser-3d-carousel'),
            controller: _pageController,
            physics: const BouncingScrollPhysics(),
            itemCount: widget.tabs.length,
            onPageChanged: (idx) {
              setState(() => _currentPage = idx);
              HapticFeedback.selectionClick();
              widget.onSelectTab(widget.tabs[idx].id);
            },
            itemBuilder: (context, index) {
              final tab = widget.tabs[index];
              final isCurrent = index == _currentPage;
              final isNearby = (index - _currentPage).abs() <= 1;

              return Browser3DCarouselPage(
                controller: _pageController,
                index: index,
                currentPage: _currentPage,
                onActivate: () => _pageController.animateToPage(
                  index,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isLand ? 6 : 8,
                    vertical: isLand ? 4 : 22,
                  ),
                  child: BrowserCarouselCard(
                    tab: tab,
                    isCurrent: isCurrent,
                    onSelect: () {
                      if (isCurrent) {
                        widget.onOpenFocused();
                      } else {
                        _pageController.animateToPage(
                          index,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOutCubic,
                        );
                      }
                    },
                    onClose: () => widget.onCloseTab(tab.id),
                    child: SingleBrowserInstanceWidget(
                      key: widget.instanceKeyForTab(tab.id),
                      tab: tab,
                      fillHeight: true,
                      showCardHeader: false,
                      isMinimized: false,
                      isMaximized: true,
                      isCurrentActive: isCurrent || isNearby,
                      currentZoom: widget.currentZoom,
                      isDesktopMode: widget.isDesktopMode,
                      isDarkModeWeb: widget.isDarkModeWeb,
                      onToggleMinimize: () => widget.onToggleMinimize(tab.id),
                      onToggleMaximize: () => widget.onToggleMaximize(tab.id),
                      onClose: () => widget.onCloseTab(tab.id),
                      onControllerCreated: (c) =>
                          widget.onControllerCreated?.call(tab.id, c),
                      onNavigate: widget.onNavigate,
                      onExternalPrompt: widget.onExternalPrompt,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        // Indicador de pestañas en cápsula esmerilada
        Padding(
          padding: EdgeInsets.only(top: isLand ? 2 : 4, bottom: isLand ? 4 : 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(widget.tabs.length, (idx) {
                final isSel = idx == _currentPage;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 2.5),
                  width: isSel ? 18 : 6,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isSel
                        ? (isDark ? const Color(0xFF38BDF8) : const Color(0xFF007AFF))
                        : (isDark ? Colors.white24 : Colors.black12),
                    borderRadius: BorderRadius.circular(2),
                  ),
                );
              }),
            ),
          ),
        ),
      ],
    );
  }
}
