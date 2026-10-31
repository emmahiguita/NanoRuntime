// nano_standalone_dock_layer.dart — Dock flotante inferior para pantallas autónomas.
// QUÉ HACE: Renderiza barra de navegación o píldora en pantallas autónomas fuera de ScaffoldShell.
// CÓMO FUNCIONA: Escucha nanoNavModeProvider y despacha gestos de minimizado y conversión a drawer.
// POR QUÉ: Extraído de NanoUniversalDrawerOverlay para cumplir el límite de 200 líneas (SOLID).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'nano_destination.dart';
import 'nano_drawer_router.dart';
import 'nano_fab_menu.dart';
import 'nano_nav_bar_container.dart';
import 'nano_nav_destinations_dock.dart';
import 'nano_nav_mini_pill.dart';
import 'nano_nav_mode_provider.dart';

class NanoStandaloneDockLayer extends ConsumerStatefulWidget {
  const NanoStandaloneDockLayer({
    super.key,
    required this.selected,
  });

  final NanoDestination selected;

  @override
  ConsumerState<NanoStandaloneDockLayer> createState() =>
      _NanoStandaloneDockLayerState();
}

class _NanoStandaloneDockLayerState
    extends ConsumerState<NanoStandaloneDockLayer> {
  Offset _dragDelta = Offset.zero;

  void _onPanEnd(DragEndDetails details) {
    final dx = _dragDelta.dx, dy = _dragDelta.dy;
    setState(() => _dragDelta = Offset.zero);
    final notifier = ref.read(nanoNavModeProvider.notifier);
    if (dy > 20 || (details.velocity.pixelsPerSecond.dy > 260 && dy > 8)) {
      HapticFeedback.lightImpact();
      notifier.minimizeToPill();
    } else if (dx.abs() > 38) {
      HapticFeedback.mediumImpact();
      notifier.convertToDrawer(right: dx > 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final navState = ref.watch(nanoNavModeProvider);
    final media = MediaQuery.of(context);
    final theme = Theme.of(context);
    final notifier = ref.read(nanoNavModeProvider.notifier);

    return Stack(
      children: [
        if (navState.isFabMenuOpen)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: notifier.closeFabMenu,
              child: const ColoredBox(color: Colors.transparent),
            ),
          ),
        Positioned(
          left: 16,
          right: 16,
          bottom: media.padding.bottom + 8.0,
          child: navState.isMinimizedPill
              ? Center(
                  child: NanoNavMiniPill(
                    semanticLabel: 'Mostrar navegación',
                    destination: widget.selected,
                    onExpand: notifier.expandFromPill,
                  ),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (navState.isFabMenuOpen) ...[
                      NanoFabMenu(brightness: theme.brightness),
                      const SizedBox(height: 10),
                    ],
                    GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onPanStart: (_) => _dragDelta = Offset.zero,
                      onPanUpdate: (d) => _dragDelta += d.delta,
                      onPanEnd: _onPanEnd,
                      onPanCancel: () => _dragDelta = Offset.zero,
                      child: NanoNavBarContainer(
                        compact: true,
                        radius: 26,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          child: NanoNavDestinationsDock(
                            selected: widget.selected,
                            brightness: theme.brightness,
                            compact: true,
                            onSelect: navigateFromNanoDrawer,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}
