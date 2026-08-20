import 'package:flutter/material.dart';
import '../../theme/design_tokens.dart';
import 'nano_dock_controller.dart';

/// Controles compactos del panel de navegación dockable (posición y colapso).
class NanoPanelControls extends StatelessWidget {
  const NanoPanelControls({
    super.key,
    required this.colors,
    required this.dockController,
  });

  final NanoColors colors;
  final NanoDockController dockController;

  @override
  Widget build(BuildContext context) {
    final isTop = dockController.position == NavPosition.top;
    final isMinimized = dockController.isMinimized;

    return Flex(
      direction: isTop ? Axis.horizontal : Axis.vertical,
      mainAxisSize: MainAxisSize.min,
      children: [
        PopupMenuButton<NavPosition>(
          tooltip: 'Posición del dock',
          icon: Icon(
            Icons.tune_rounded,
            color: colors.textSecondary.withValues(alpha: 0.85),
            size: 18,
          ),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          color: colors.surfaceVariant,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          onSelected: dockController.setPosition,
          itemBuilder: (ctx) => const [
            PopupMenuItem(
              value: NavPosition.left,
              child: Text('Anclar a la Izquierda'),
            ),
            PopupMenuItem(
              value: NavPosition.top,
              child: Text('Anclar Arriba'),
            ),
            PopupMenuItem(
              value: NavPosition.right,
              child: Text('Anclar a la Derecha'),
            ),
          ],
        ),
        IconButton(
          tooltip: isMinimized ? 'Expandir' : 'Minimizar',
          icon: Icon(
            isMinimized
                ? (isTop ? Icons.expand_more_rounded : Icons.chevron_right_rounded)
                : (isTop ? Icons.expand_less_rounded : Icons.chevron_left_rounded),
            color: colors.textSecondary.withValues(alpha: 0.85),
            size: 18,
          ),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          onPressed: dockController.toggleMinimized,
        ),
      ],
    );
  }
}
