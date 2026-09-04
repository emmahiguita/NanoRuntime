import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/design_tokens.dart';
import '../router/app_router.dart';
import '../theme/nano_breakpoint.dart';
import '../widgets/liquid_fluid_background.dart';
import '../widgets/nano_ambient_background.dart';
import '../widgets/navigation/nano_navigation_panel.dart';

/// Shell principal: conserva los stacks de cada pestaña y entrega la
/// navegación visual al único FAB glass compartido por toda la aplicación.
class ScaffoldShell extends StatelessWidget {
  const ScaffoldShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  // UI-REV-08: el último acceso del panel no es una pestaña del shell — es
  // el atajo a la pantalla de Automatización (ruta global /automation, la
  // misma que abre el Inicio). Se navega con push, no con goBranch.
  static const int _automationShortcutIndex = 5;

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
    // Acceso directo a Automatización (mismo icono que su tarjeta en Inicio).
    (
      icon: Icons.auto_awesome_outlined,
      sel: Icons.auto_awesome_rounded,
      label: 'Automatización',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final currentIndex = shell.currentIndex;
    final branchCanPop =
        AppRouter.branchKeys[currentIndex].currentState?.canPop() ?? false;
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    // UI-REV-08: en claro el fondo es la aurora líquida naranja (la misma de
    // dev/automation); en oscuro se conserva el ambient con glows orbitales.
    final isDark =
        Theme.of(context).extension<NanoThemeExtension>()!.colors
            is NanoDarkColors;

    final shellContent = MediaQuery.removePadding(
      context: context,
      removeTop: true,
      removeBottom: true,
      removeLeft: true,
      removeRight: true,
      child: shell,
    );
    final boundedContent = Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: NanoBreakpoints.contentMaxWidth,
        ),
        child: shellContent,
      ),
    );

    return PopScope(
      canPop: currentIndex == 0 || branchCanPop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && currentIndex != 0) shell.goBranch(0);
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: isDark
                  ? const NanoAmbientBackground()
                  : const LiquidFluidBackground(),
            ),
            SafeArea(
              child: NanoFloatingNavigationFrame(
                hidden: keyboardOpen,
                tabs: _tabs,
                selectedIndex: currentIndex,
                onDestinationSelected: (index) {
                  if (index == _automationShortcutIndex) {
                    context.push('/automation');
                    return;
                  }
                  shell.goBranch(index, initialLocation: index == currentIndex);
                },
                child: boundedContent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
