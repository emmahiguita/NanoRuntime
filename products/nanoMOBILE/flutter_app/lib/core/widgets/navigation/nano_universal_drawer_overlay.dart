// nano_universal_drawer_overlay.dart — Capa flotante universal de navegación estilo iOS Liquid Glass.
// QUÉ HACE: Despliega la navegación oficial de Nano AI (búho superior, píldora o dock inferior) en toda ruta.
// CÓMO FUNCIONA: Escucha nanoNavModeProvider y soporta gestos para contraer a píldora o convertir a Drawer.
// POR QUÉ: Garantiza que la barra de navegación sea siempre la misma y tenga todos sus modos limpios (< 180 líneas).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../router/app_router.dart';
import 'nano_destination.dart';
import 'nano_drawer_drop_button.dart';
import 'nano_drawer_router.dart';
import 'nano_fab_menu.dart';
import 'nano_nav_bar_container.dart';
import 'nano_nav_destinations_dock.dart';
import 'nano_nav_floating_window.dart';
import 'nano_nav_mini_pill.dart';
import 'nano_nav_mode_provider.dart';

class NanoDrawerContentInset extends StatelessWidget {
  const NanoDrawerContentInset({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => child;
}

class NanoUniversalDrawerOverlay extends ConsumerStatefulWidget {
  const NanoUniversalDrawerOverlay({super.key});
  @override
  ConsumerState<NanoUniversalDrawerOverlay> createState() =>
      _NanoUniversalDrawerOverlayState();
}

class _NanoUniversalDrawerOverlayState
    extends ConsumerState<NanoUniversalDrawerOverlay> {
  Offset _dragDelta = Offset.zero;

  @override
  void initState() {
    super.initState();
    AppRouter.router.routerDelegate.addListener(_routeChanged);
  }

  @override
  void dispose() {
    AppRouter.router.routerDelegate.removeListener(_routeChanged);
    super.dispose();
  }

  void _routeChanged() {
    if (mounted) setState(() {});
  }

  String _currentRoute() {
    try {
      final matches =
          AppRouter.router.routerDelegate.currentConfiguration.matches;
      if (matches.isNotEmpty) return matches.last.matchedLocation;
      return AppRouter.router.routerDelegate.currentConfiguration.uri.toString();
    } catch (_) {
      return '/dashboard';
    }
  }

  NanoDestination _resolveSelected() => switch (_currentRoute()) {
    final loc when loc.startsWith('/models') => NanoDestination.models,
    final loc when loc.startsWith('/terminal') => NanoDestination.terminal,
    final loc when loc.startsWith('/settings') => NanoDestination.settings,
    _ => NanoDestination.automation,
  };

  bool _isStandaloneScreen() {
    final loc = _currentRoute();
    return const [
      '/automation/messages',
      '/automation/whatsapp',
      '/automation/skills',
      '/chat',
      '/browser',
      '/desktop',
      '/database',
      '/linux',
      '/account',
    ].any(loc.startsWith);
  }

  /// Evalúa el gesto sobre la barra inferior: hacia abajo minimiza a píldora; lateral abre Drawer.
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
    final selected = _resolveSelected();
    final notifier = ref.read(nanoNavModeProvider.notifier);

    if (navState.isDrawerMode) {
      return Stack(
        children: [
          if (navState.isDrawerOpen)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: notifier.closeDrawerMenu,
                child: const ColoredBox(color: Colors.transparent),
              ),
            ),
          Positioned(
            top: media.padding.top + 8.0,
            left: 14.0,
            child: NanoDrawerDropButton(
              isOpen: navState.isDrawerOpen,
              primary: theme.colorScheme.primary,
              onTap: notifier.toggleDrawerMenu,
              onDragDown: notifier.convertToBottomBar,
            ),
          ),
          if (navState.isDrawerOpen)
            NanoNavFloatingWindow(
              selected: selected,
              isRight: navState.drawerOnRight,
              onDestinationSelected: (dest) {
                notifier.closeDrawerMenu();
                navigateFromNanoDrawer(dest);
              },
              onCloseMenu: notifier.closeDrawerMenu,
              onRestoreBottom: notifier.convertToBottomBar,
            ),
        ],
      );
    }

    if (!_isStandaloneScreen()) return const SizedBox.shrink();

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
                    destination: selected,
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
                            selected: selected,
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
