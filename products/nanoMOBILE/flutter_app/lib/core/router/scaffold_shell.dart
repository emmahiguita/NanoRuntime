import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/design_tokens.dart';
import '../widgets/navigation/nano_dock_controller.dart';
import '../widgets/navigation/nano_navigation_panel.dart';

export '../widgets/navigation/nano_dock_controller.dart' show NavPosition;

/// Shell principal de la aplicación que orquesta la navegación, el dock y el contenido.
class ScaffoldShell extends StatefulWidget {
  final StatefulNavigationShell shell;
  const ScaffoldShell({super.key, required this.shell});

  @override
  State<ScaffoldShell> createState() => _ScaffoldShellState();
}

class _ScaffoldShellState extends State<ScaffoldShell> {
  static const List<NavTabSpec> _tabs = [
    (
      icon: Icons.dashboard_outlined,
      sel: Icons.dashboard_rounded,
      label: 'Inicio',
    ),
    (icon: Icons.chat_outlined, sel: Icons.chat_rounded, label: 'Chat'),
    (
      icon: Icons.extension_outlined,
      sel: Icons.extension_rounded,
      label: 'Modelos',
    ),
    (
      icon: Icons.terminal_outlined,
      sel: Icons.terminal_rounded,
      label: 'Terminal',
    ),
    (
      icon: Icons.settings_outlined,
      sel: Icons.settings_rounded,
      label: 'Ajustes',
    ),
  ];

  late final NanoDockController _dockController;

  @override
  void initState() {
    super.initState();
    _dockController = NanoDockController(initialPosition: NavPosition.left);
  }

  @override
  void dispose() {
    _dockController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;
    final currentIdx = widget.shell.currentIndex;

    return PopScope(
      canPop: currentIdx == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && currentIdx != 0) {
          widget.shell.goBranch(0);
        }
      },
      child: ListenableBuilder(
        listenable: _dockController,
        builder: (context, _) {
          final screenSize = MediaQuery.sizeOf(context);
          final screenWide = screenSize.width > 600;

          // Sincronizar estado compacto si la pantalla es estrecha en vertical
          if (!screenWide &&
              !_dockController.isMinimized &&
              !_dockController.isHorizontal) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted &&
                  !_dockController.isMinimized &&
                  !_dockController.isHorizontal) {
                _dockController.setMinimized(true);
              }
            });
          }

          final navPanel = NanoNavigationPanel(
            shell: widget.shell,
            dockController: _dockController,
            colors: colors,
            tabs: _tabs,
          );

          final isTop = _dockController.position == NavPosition.top;
          final isLeft = _dockController.position == NavPosition.left;
          final isRight = _dockController.position == NavPosition.right;

          // Eliminar insets duplicados para evitar solapamientos con las pantallas hijas
          final shellContent = MediaQuery.removePadding(
            context: context,
            removeTop: isTop,
            removeLeft: isLeft,
            removeRight: isRight,
            child: widget.shell,
          );

          Widget layoutContent;
          if (isTop) {
            layoutContent = Column(
              children: [
                navPanel,
                Expanded(child: shellContent),
              ],
            );
          } else {
            layoutContent = Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (isLeft) navPanel,
                Expanded(child: shellContent),
                if (isRight) navPanel,
              ],
            );
          }

          return Scaffold(
            backgroundColor: colors.background,
            body: SafeArea(
              child: Stack(
                children: [
                  Positioned.fill(child: layoutContent),

                  // Indicador visual de zona magnética al arrastrar el dock
                  if (_dockController.isDragging &&
                      _dockController.activeDropZone != DockDropZone.none)
                    _buildDropZoneIndicator(
                      context,
                      colors,
                      _dockController.activeDropZone,
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDropZoneIndicator(
    BuildContext context,
    NanoColors colors,
    DockDropZone zone,
  ) {
    Alignment alignment;
    double? width;
    double? height;

    switch (zone) {
      case DockDropZone.top:
        alignment = Alignment.topCenter;
        width = double.infinity;
        height = 60;
        break;
      case DockDropZone.left:
        alignment = Alignment.centerLeft;
        width = 70;
        height = double.infinity;
        break;
      case DockDropZone.right:
        alignment = Alignment.centerRight;
        width = 70;
        height = double.infinity;
        break;
      case DockDropZone.none:
        return const SizedBox.shrink();
    }

    return Align(
      alignment: alignment,
      child: IgnorePointer(
        child: Container(
          width: width,
          height: height,
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: colors.primary.withValues(alpha: 0.6),
              width: 2,
            ),
            color: colors.primary.withValues(alpha: 0.12),
          ),
        ),
      ),
    );
  }
}
