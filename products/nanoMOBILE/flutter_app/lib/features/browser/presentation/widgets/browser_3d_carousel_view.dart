import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:nanoai/features/browser/domain/browser_tab_model.dart';
import 'package:nanoai/features/browser/presentation/widgets/single_browser_instance_widget.dart';

/// Visor 3D y Carrusel con Perspectiva Espacial de Navegadores Web Reales.
/// Muestra las ventanas activas en un carrusel 3D con rotación Y, escala dinámica,
/// indicadores de posición y soporte táctil fluido sin recargas.
class Browser3DCarouselView extends StatefulWidget {
  final List<BrowserTabModel> tabs;
  final String activeTabId;
  final ValueChanged<String> onSelectTab;
  final VoidCallback onOpenFocused;
  final ValueChanged<String> onCloseTab;
  final ValueChanged<String> onToggleMaximize;
  final ValueChanged<String> onToggleMinimize;
  final Set<String> minimizedWindowIds;
  final String? maximizedWindowId;
  final double currentZoom;
  final bool isDesktopMode;
  final bool isDarkModeWeb;
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
  late PageController _pageController;
  int _currentPage = 0;
  bool? _wasLandscape;

  @override
  void initState() {
    super.initState();
    final initialIndex = widget.tabs.indexWhere((t) => t.id == widget.activeTabId);
    _currentPage = initialIndex >= 0 ? initialIndex : 0;
    _pageController = PageController(
      initialPage: _currentPage,
      viewportFraction: 0.84,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    final targetFraction = isLandscape ? 0.48 : 0.82;
    if (_wasLandscape != null && _wasLandscape != isLandscape) {
      final oldController = _pageController;
      _pageController = PageController(
        initialPage: _currentPage,
        viewportFraction: targetFraction,
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        oldController.dispose();
      });
    } else if (_wasLandscape == null && targetFraction != 0.84) {
      final oldController = _pageController;
      _pageController = PageController(
        initialPage: _currentPage,
        viewportFraction: targetFraction,
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        oldController.dispose();
      });
    }
    _wasLandscape = isLandscape;
  }

  @override
  void didUpdateWidget(covariant Browser3DCarouselView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.activeTabId != oldWidget.activeTabId) {
      final index = widget.tabs.indexWhere((t) => t.id == widget.activeTabId);
      if (index >= 0 && index != _currentPage && _pageController.hasClients) {
        _currentPage = index;
        _pageController.animateToPage(
          index,
          duration: const Duration(milliseconds: 320),
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
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    if (widget.tabs.isEmpty) {
      return const Center(
        child: Text(
          'No hay ventanas activas',
          style: TextStyle(color: Color(0xFF94A3B8)),
        ),
      );
    }

    return Column(
      children: [
        // Área principal del Carrusel 3D
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            physics: const BouncingScrollPhysics(),
            itemCount: widget.tabs.length,
            onPageChanged: (index) {
              setState(() => _currentPage = index);
              HapticFeedback.selectionClick();
              widget.onSelectTab(widget.tabs[index].id);
            },
            itemBuilder: (context, index) {
              final tab = widget.tabs[index];
              final isMax = widget.maximizedWindowId == tab.id;

              return AnimatedBuilder(
                animation: _pageController,
                builder: (context, child) {
                  double value = 0.0;
                  if (_pageController.position.haveDimensions) {
                    value = (_pageController.page ?? _pageController.initialPage.toDouble()) - index;
                  } else {
                    value = (_currentPage - index).toDouble();
                  }

                  // Efecto escénico 3D compatible con aceleración gráfica de WebView nativo
                  final scale = (1.0 - (value.abs() * 0.12)).clamp(0.86, 1.0);
                  final translateY = (value.abs() * 16.0).clamp(0.0, 26.0);
                  final dimFactor = (value.abs() * 0.35).clamp(0.0, 0.45);

                  final transform = Matrix4.identity()
                    ..translateByDouble(0.0, translateY, 0.0, 1.0)
                    ..scaleByDouble(scale, scale, 1.0, 1.0);
                  final isCurrent = index == _currentPage;

                  Widget cardWidget = Stack(
                    children: [
                      IgnorePointer(
                        ignoring: !isCurrent,
                        child: child!,
                      ),
                      if (dimFactor > 0.02)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: dimFactor),
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ),
                    ],
                  );

                  // Si la tarjeta está a los costados, tocarla la desplaza al centro sin salir de 3D
                  if (!isCurrent) {
                    cardWidget = GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        _pageController.animateToPage(
                          index,
                          duration: const Duration(milliseconds: 320),
                          curve: Curves.easeOutCubic,
                        );
                      },
                      child: cardWidget,
                    );
                  }

                  return Transform(
                    alignment: Alignment.center,
                    transform: transform,
                    child: cardWidget,
                  );
                },
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isLandscape ? 4 : 6,
                    vertical: isLandscape ? 2 : 8,
                  ),
                  child: SingleBrowserInstanceWidget(
                    key: ValueKey('3d_card_${tab.id}'),
                    tab: tab,
                    fillHeight: true,
                    showCardHeader: true,
                    isMinimized: false,
                    isMaximized: isMax,
                    isCurrentActive: tab.id == widget.activeTabId,
                    currentZoom: widget.currentZoom,
                    isDesktopMode: widget.isDesktopMode,
                    isDarkModeWeb: widget.isDarkModeWeb,
                    onSelectTab: null,
                    onToggleMinimize: () => widget.onToggleMinimize(tab.id),
                    onToggleMaximize: () => widget.onToggleMaximize(tab.id),
                    onClose: () => widget.onCloseTab(tab.id),
                    onControllerCreated: (ctrl) => widget.onControllerCreated?.call(tab.id, ctrl),
                    onNavigate: widget.onNavigate,
                    onExternalPrompt: widget.onExternalPrompt,
                  ),
                ),
              );
            },
          ),
        ),

        // Barra inferior de indicador 3D con puntos y subtítulo
        Padding(
          padding: EdgeInsets.only(top: isLandscape ? 1 : 4, bottom: isLandscape ? 2 : 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Puntos indicadores de posición
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(widget.tabs.length, (idx) {
                  final isSelected = idx == _currentPage;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    margin: const EdgeInsets.symmetric(horizontal: 2.5),
                    width: isSelected ? (isLandscape ? 14 : 22) : (isLandscape ? 5 : 6),
                    height: isLandscape ? 3 : 5,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF10B981)
                          : const Color(0xFF334155),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  );
                }),
              ),
              if (!isLandscape) ...[
                const SizedBox(height: 4),
                const Text(
                  'Navegación 3D activa • Desliza carrusel o toca laterales',
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFF94A3B8),
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
