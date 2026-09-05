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

  @override
  Widget build(BuildContext context) {
    final currentIndex = shell.currentIndex;
    final branchCanPop =
        AppRouter.branchKeys[currentIndex].currentState?.canPop() ?? false;
    // UI-REV-08/09: en claro el fondo es la aurora líquida (la misma de
    // dev/automation); el oscuro normal conserva el ambient con glows
    // orbitales. La identidad "Clásico" (familia oscura de dev,
    // isClassicOrange) también usa la aurora líquida. NAV-BAR-FIX-05: la
    // gama de la aurora es la azul de la barra de navegación.
    final shellColors = Theme.of(
      context,
    ).extension<NanoThemeExtension>()!.colors;
    final isDark = shellColors is NanoDarkColors;
    final useLiquid = !isDark || shellColors.isClassicOrange;

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
              child: useLiquid
                  ? const LiquidFluidBackground()
                  : const NanoAmbientBackground(),
            ),
            SafeArea(
              child: NanoFloatingNavigationFrame(
                tabs: nanoShellTabs,
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
