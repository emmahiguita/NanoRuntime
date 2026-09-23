import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:nanoai/features/browser/domain/browser_tab_model.dart';
import 'package:nanoai/features/browser/presentation/widgets/single_browser_instance_widget.dart';

/// Visor 3D y Carrusel con Perspectiva Espacial de Navegadores Web Reales.
/// 
/// - QUÉ HACE: Muestra las pestañas en carrusel tridimensional animado con escala y profundidad.
/// - CÓMO FUNCIONA: Usa [PageView.builder] con [AnimatedBuilder] y transformaciones de matriz 3D.
/// - POR QUÉ: Permite visualización inmersiva manteniendo claves estables sin reiniciar la sesión (<200 líneas).
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
  final void Function(String tabId, InAppWebViewController ctrl)? onControllerCreated;
  final ValueChanged<String>? onNavigate;
  final void Function(String url)? onExternalPrompt;

  const Browser3DCarouselView({
    super.key, required this.tabs, required this.activeTabId, required this.onSelectTab,
    required this.onOpenFocused, required this.onCloseTab, required this.onToggleMaximize,
    required this.onToggleMinimize, required this.minimizedWindowIds, this.maximizedWindowId,
    this.currentZoom = 1.0, this.isDesktopMode = false, this.isDarkModeWeb = false,
    this.onControllerCreated, this.onNavigate, this.onExternalPrompt,
  });

  @override
  State<Browser3DCarouselView> createState() => _Browser3DCarouselViewState();
}

class _Browser3DCarouselViewState extends State<Browser3DCarouselView> {
  late PageController _pageController;
  int _currentPage = 0;
  bool? _wasLandscape;

  @override
  void initState() {
    super.initState();
    final idx = widget.tabs.indexWhere((t) => t.id == widget.activeTabId);
    _currentPage = idx >= 0 ? idx : 0;
    _pageController = PageController(initialPage: _currentPage, viewportFraction: 0.84);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final isLand = MediaQuery.of(context).orientation == Orientation.landscape;
    final frac = isLand ? 0.48 : 0.82;
    if (_wasLandscape != null && _wasLandscape != isLand) {
      final old = _pageController;
      _pageController = PageController(initialPage: _currentPage, viewportFraction: frac);
      WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
    }
    _wasLandscape = isLand;
  }

  @override
  void didUpdateWidget(covariant Browser3DCarouselView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.activeTabId != oldWidget.activeTabId) {
      final idx = widget.tabs.indexWhere((t) => t.id == widget.activeTabId);
      if (idx >= 0 && idx != _currentPage && _pageController.hasClients) {
        _currentPage = idx;
        _pageController.animateToPage(idx, duration: const Duration(milliseconds: 320), curve: Curves.easeOutCubic);
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
    final isLand = MediaQuery.of(context).orientation == Orientation.landscape;
    if (widget.tabs.isEmpty) return const Center(child: Text('No hay ventanas activas', style: TextStyle(color: Color(0xFF94A3B8))));

    return Column(children: [
      Expanded(
        child: PageView.builder(
          controller: _pageController, physics: const BouncingScrollPhysics(), itemCount: widget.tabs.length,
          onPageChanged: (idx) {
            setState(() => _currentPage = idx);
            HapticFeedback.selectionClick();
            widget.onSelectTab(widget.tabs[idx].id);
          },
          itemBuilder: (context, index) {
            final tab = widget.tabs[index];
            final isMax = widget.maximizedWindowId == tab.id;
            return AnimatedBuilder(
              animation: _pageController,
              builder: (ctx, child) {
                double val = _pageController.position.haveDimensions
                    ? (_pageController.page ?? _pageController.initialPage.toDouble()) - index
                    : (_currentPage - index).toDouble();
                final scale = (1.0 - (val.abs() * 0.12)).clamp(0.86, 1.0);
                final translateY = (val.abs() * 16.0).clamp(0.0, 26.0);
                final dim = (val.abs() * 0.35).clamp(0.0, 0.45);
                final isCurrent = index == _currentPage;

                Widget card = Stack(children: [
                  IgnorePointer(ignoring: !isCurrent, child: child!),
                  if (dim > 0.02) Positioned.fill(child: IgnorePointer(child: Container(
                    decoration: BoxDecoration(color: Colors.black.withValues(alpha: dim), borderRadius: BorderRadius.circular(12)),
                  ))),
                ]);
                if (!isCurrent) {
                  card = GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _pageController.animateToPage(index, duration: const Duration(milliseconds: 320), curve: Curves.easeOutCubic),
                    child: card,
                  );
                }
                return Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()..translateByDouble(0.0, translateY, 0.0, 1.0)..scaleByDouble(scale, scale, 1.0, 1.0),
                  child: card,
                );
              },
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: isLand ? 4 : 6, vertical: isLand ? 2 : 6),
                child: SingleBrowserInstanceWidget(
                  key: ValueKey('browser_instance_${tab.id}'), tab: tab, fillHeight: true, showCardHeader: true,
                  isMinimized: false, isMaximized: isMax, isCurrentActive: tab.id == widget.activeTabId,
                  currentZoom: widget.currentZoom, isDesktopMode: widget.isDesktopMode, isDarkModeWeb: widget.isDarkModeWeb,
                  onToggleMinimize: () => widget.onToggleMinimize(tab.id), onToggleMaximize: () => widget.onToggleMaximize(tab.id),
                  onClose: () => widget.onCloseTab(tab.id), onControllerCreated: (c) => widget.onControllerCreated?.call(tab.id, c),
                  onNavigate: widget.onNavigate, onExternalPrompt: widget.onExternalPrompt,
                ),
              ),
            );
          },
        ),
      ),
      Padding(
        padding: EdgeInsets.only(top: isLand ? 1 : 3, bottom: isLand ? 2 : 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(widget.tabs.length, (idx) {
            final isSel = idx == _currentPage;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              margin: const EdgeInsets.symmetric(horizontal: 2.0),
              width: isSel ? (isLand ? 14 : 20) : (isLand ? 4 : 5),
              height: isLand ? 3 : 4,
              decoration: BoxDecoration(color: isSel ? const Color(0xFF10B981) : const Color(0xFF334155), borderRadius: BorderRadius.circular(2)),
            );
          }),
        ),
      ),
    ]);
  }
}
