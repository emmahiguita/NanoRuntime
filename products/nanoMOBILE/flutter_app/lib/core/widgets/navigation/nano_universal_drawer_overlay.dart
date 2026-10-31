// nano_universal_drawer_overlay.dart — Capa flotante universal de navegación estilo iOS Liquid Glass.
// QUÉ HACE: Despliega la navegación oficial de Nano AI (búho superior, píldora o dock inferior) en toda ruta.
// CÓMO FUNCIONA: Escucha nanoNavModeProvider y previene barras duplicadas en pantallas dentro de ScaffoldShell.
// POR QUÉ: Garantiza navegación consistente y elimina solapamientos y duplicados visuales (< 140 líneas).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../router/app_router.dart';
import 'nano_destination.dart';
import 'nano_drawer_drop_button.dart';
import 'nano_drawer_router.dart';
import 'nano_nav_floating_window.dart';
import 'nano_nav_mode_provider.dart';
import 'nano_standalone_dock_layer.dart';

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

  /// Pantallas autónomas que requieren dock flotante propio.
  /// EXCLUYE estrictamente rutas de ScaffoldShell y ChatScreen para evitar duplicados visuales.
  bool _isStandaloneScreen() {
    final loc = _currentRoute();
    if (loc.startsWith('/dashboard') ||
        loc.startsWith('/automation') && !loc.startsWith('/automation/') ||
        loc.startsWith('/models') ||
        loc.startsWith('/terminal') ||
        loc.startsWith('/linux') ||
        loc.startsWith('/database') ||
        loc.startsWith('/settings') ||
        loc.startsWith('/chat')) {
      return false;
    }
    return const [
      '/browser',
      '/desktop',
    ].any(loc.startsWith);
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

    return NanoStandaloneDockLayer(selected: selected);
  }
}
