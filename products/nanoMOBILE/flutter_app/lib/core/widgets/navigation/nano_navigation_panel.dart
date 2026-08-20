import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../theme/design_tokens.dart';
import '../nano_shader_host.dart';
import 'nano_dock_controller.dart';
import 'nano_dock_handle.dart';
import 'nano_panel_controls.dart';
import 'nano_selection_morph.dart';

typedef NavTabSpec = ({IconData icon, IconData sel, String label});

/// Panel de navegación interactivo con física, arrastre dinámico y estética líquida óptica flotante.
class NanoNavigationPanel extends StatefulWidget {
  const NanoNavigationPanel({
    super.key,
    required this.shell,
    required this.dockController,
    required this.colors,
    required this.tabs,
  });

  final StatefulNavigationShell shell;
  final NanoDockController dockController;
  final NanoColors colors;
  final List<NavTabSpec> tabs;

  @override
  State<NanoNavigationPanel> createState() => _NanoNavigationPanelState();
}

class _NanoNavigationPanelState extends State<NanoNavigationPanel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _timeController;
  Offset _pointerPosition = const Offset(100, 100);
  FragmentShader? _shader;

  @override
  void initState() {
    super.initState();
    _timeController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();

    _shader = NanoShaderHost.createShader();
  }

  @override
  void dispose() {
    _timeController.dispose();
    _shader?.dispose();
    super.dispose();
  }

  void _onPointerHover(PointerEvent event) {
    setState(() {
      _pointerPosition = event.localPosition;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    final isDark = colors is NanoDarkColors;
    final isTop = widget.dockController.position == NavPosition.top;
    final isMinimized = widget.dockController.isMinimized;
    final currentIdx = widget.shell.currentIndex;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final isDragging = widget.dockController.isDragging;
    final screenSize = MediaQuery.sizeOf(context);

    final panelBorderRadius = BorderRadius.circular(isTop ? 22 : 28);

    // Contenido estructurado según orientación
    Widget innerContent;
    if (isTop) {
      innerContent = Row(
        mainAxisSize: MainAxisSize.max,
        children: [
          NanoDockHandle(colors: colors, dockController: widget.dockController),
          const SizedBox(width: 4),
          Expanded(
            child: NanoSelectionMorphBar(
              tabs: widget.tabs,
              selectedIndex: currentIdx,
              colors: colors,
              position: widget.dockController.position,
              isMinimized: isMinimized,
              onTabSelected: (idx) => widget.shell.goBranch(
                idx,
                initialLocation: idx == currentIdx,
              ),
            ),
          ),
          NanoPanelControls(
            colors: colors,
            dockController: widget.dockController,
          ),
          const SizedBox(width: 4),
        ],
      );
    } else {
      // En horizontal la altura útil puede ser menor que la suma de las cinco
      // pestañas, el asa y los controles. El dock conserva todas las acciones
      // accesibles mediante desplazamiento en vez de desbordar el RenderFlex.
      innerContent = SingleChildScrollView(
        primary: false,
        physics: const ClampingScrollPhysics(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 6),
            NanoDockHandle(
              colors: colors,
              dockController: widget.dockController,
            ),
            const SizedBox(height: 6),
            NanoSelectionMorphBar(
              tabs: widget.tabs,
              selectedIndex: currentIdx,
              colors: colors,
              position: widget.dockController.position,
              isMinimized: isMinimized,
              onTabSelected: (idx) => widget.shell.goBranch(
                idx,
                initialLocation: idx == currentIdx,
              ),
            ),
            const SizedBox(height: 4),
            NanoPanelControls(
              colors: colors,
              dockController: widget.dockController,
            ),
            const SizedBox(height: 6),
          ],
        ),
      );
    }

    final double width = isTop ? double.infinity : (isMinimized ? 46.0 : 124.0);
    final double? height = isTop ? (isMinimized ? 48.0 : 56.0) : null;

    EdgeInsets padding;
    if (widget.dockController.position == NavPosition.top) {
      padding = const EdgeInsets.fromLTRB(8, 4, 8, 2);
    } else if (widget.dockController.position == NavPosition.left) {
      padding = const EdgeInsets.fromLTRB(6, 4, 2, 4);
    } else {
      padding = const EdgeInsets.fromLTRB(2, 4, 6, 4);
    }

    return GestureDetector(
      onPanStart: widget.dockController.onDragStart,
      onPanUpdate: (details) =>
          widget.dockController.onDragUpdate(details, screenSize),
      onPanEnd: widget.dockController.onDragEnd,
      behavior: HitTestBehavior.translucent,
      child: Transform.translate(
        offset: widget.dockController.dragOffset,
        child: Padding(
          padding: padding,
          child: MouseRegion(
            onHover: _onPointerHover,
            child: AnimatedContainer(
              duration: isDragging
                  ? Duration.zero
                  : const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              width: isTop ? null : width,
              height: height,
              decoration: BoxDecoration(
                borderRadius: panelBorderRadius,
                boxShadow: [
                  BoxShadow(
                    color: isDragging
                        ? colors.primary.withValues(alpha: 0.35)
                        : Colors.black.withValues(alpha: isDark ? 0.30 : 0.08),
                    blurRadius: isDragging ? 26 : 18,
                    spreadRadius: isDragging ? 2 : -4,
                    offset: const Offset(0, 4),
                  ),
                  if (isDragging)
                    BoxShadow(
                      color: colors.accentCyan.withValues(alpha: 0.25),
                      blurRadius: 32,
                      spreadRadius: 4,
                    ),
                ],
              ),
              child: ClipRRect(
                borderRadius: panelBorderRadius,
                child: RepaintBoundary(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Stack(
                      children: [
                        // Capa 1: GPU Fragment Shader o Fallback Liquid Glass
                        if (_shader != null && !reduceMotion)
                          Positioned.fill(
                            child: AnimatedBuilder(
                              animation: _timeController,
                              builder: (context, _) => CustomPaint(
                                painter: NanoOpticalShaderPainter(
                                  shader: _shader!,
                                  time: _timeController.value * 20.0,
                                  pointer: _pointerPosition,
                                  colors: colors,
                                  intensity: isDark ? 0.9 : 0.7,
                                  refraction: 1.0,
                                  fresnel: 1.1,
                                ),
                              ),
                            ),
                          )
                        else
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: panelBorderRadius,
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: isDark
                                      ? [
                                          colors.backgroundPrimary.withValues(
                                            alpha: 0.88,
                                          ),
                                          colors.surface.withValues(
                                            alpha: 0.70,
                                          ),
                                          colors.surfaceVariant.withValues(
                                            alpha: 0.50,
                                          ),
                                        ]
                                      : [
                                          Colors.white.withValues(alpha: 0.88),
                                          colors.surface.withValues(
                                            alpha: 0.75,
                                          ),
                                          colors.surfaceVariant.withValues(
                                            alpha: 0.60,
                                          ),
                                        ],
                                ),
                                border: Border.all(
                                  width: isDragging ? 1.5 : 0.8,
                                  color: isDragging
                                      ? colors.primary
                                      : Colors.white.withValues(
                                          alpha: isDark ? 0.18 : 0.55,
                                        ),
                                ),
                              ),
                            ),
                          ),

                        // Capa 2: Contenido interactivo
                        innerContent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
