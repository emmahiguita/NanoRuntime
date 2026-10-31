// nano_universal_drawer_overlay.dart — Capa flotante universal de navegación estilo iOS Liquid Glass.
// QUÉ HACE: Despliega la navegación (búho superior o dock inferior) universalmente en cualquier pantalla.
// CÓMO FUNCIONA: Elimina franjas negras; en modo drawer despliega botón superior y en barra dock inferior.
// POR QUÉ: Garantiza que la navegación esté siempre visible y accesible en cualquier ruta (< 160 líneas).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../router/app_router.dart';
import 'nano_destination.dart';
import 'nano_drawer_drop_button.dart';
import 'nano_drawer_router.dart';
import 'nano_nav_bar_container.dart';
import 'nano_nav_destinations_dock.dart';
import 'nano_nav_floating_window.dart';
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

  NanoDestination _resolveSelected() {
    String location = '';
    try {
      location = AppRouter.router.routerDelegate.currentConfiguration.uri
          .toString();
    } catch (_) {
      location = '/dashboard';
    }
    return switch (location) {
      final loc when loc.startsWith('/models') => NanoDestination.models,
      final loc when loc.startsWith('/terminal') => NanoDestination.terminal,
      final loc when loc.startsWith('/settings') => NanoDestination.settings,
      _ => NanoDestination.automation,
    };
  }

  bool _isStandaloneScreen() {
    String location = '';
    try {
      location = AppRouter.router.routerDelegate.currentConfiguration.uri
          .toString();
    } catch (_) {
      location = '/dashboard';
    }
    return location.startsWith('/automation/messages') ||
        location.startsWith('/automation/whatsapp') ||
        location.startsWith('/automation/skills') ||
        location.startsWith('/chat') ||
        location.startsWith('/browser') ||
        location.startsWith('/desktop');
  }

  @override
  Widget build(BuildContext context) {
    final navState = ref.watch(nanoNavModeProvider);
    final media = MediaQuery.of(context);
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final selected = _resolveSelected();

    // 1. MODO DRAWER: Botón búho superior + Popover flotante iOS Liquid Glass
    if (navState.isDrawerMode) {
      if (_isStandaloneScreen()) {
        return const SizedBox.shrink();
      }
      return Stack(
        children: [
          if (navState.isDrawerOpen)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  ref.read(nanoNavModeProvider.notifier).closeDrawerMenu();
                },
                child: const ColoredBox(color: Colors.transparent),
              ),
            ),
          Positioned(
            top: media.padding.top + 8.0,
            left: 14.0,
            child: NanoDrawerDropButton(
              isOpen: navState.isDrawerOpen,
              primary: primary,
              onTap: () {
                ref.read(nanoNavModeProvider.notifier).toggleDrawerMenu();
              },
              onDragDown: () {
                ref.read(nanoNavModeProvider.notifier).convertToBottomBar();
              },
            ),
          ),
          if (navState.isDrawerOpen)
            NanoNavFloatingWindow(
              selected: selected,
              isRight: navState.drawerOnRight,
              onDestinationSelected: (dest) {
                ref.read(nanoNavModeProvider.notifier).closeDrawerMenu();
                navigateFromNanoDrawer(dest);
              },
              onCloseMenu: () {
                ref.read(nanoNavModeProvider.notifier).closeDrawerMenu();
              },
              onRestoreBottom: () {
                ref.read(nanoNavModeProvider.notifier).convertToBottomBar();
              },
            ),
        ],
      );
    }

    // 2. MODO BARRA INFERIOR: En pantallas independientes garantiza navegación universal
    if (_isStandaloneScreen()) {
      return Stack(
        children: [
          Positioned(
            left: 16,
            right: 16,
            bottom: media.padding.bottom + 8.0,
            child: NanoNavBarContainer(
              compact: true,
              radius: 26,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: NanoNavDestinationsDock(
                  selected: selected,
                  brightness: theme.brightness,
                  compact: true,
                  onSelect: (dest) => navigateFromNanoDrawer(dest),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }
}
