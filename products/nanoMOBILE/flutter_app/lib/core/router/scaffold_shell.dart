import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/design_tokens.dart';
import '../router/app_router.dart';
import '../theme/nano_breakpoint.dart';
import '../widgets/navigation/nano_navigation_panel.dart';
import '../../features/home/buho_wallpaper.dart';

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
    final shellColors = Theme.of(
      context,
    ).extension<NanoThemeExtension>()!.colors;
    final isDark = shellColors is NanoDarkColors;

    final location = GoRouterState.of(context).matchedLocation;
    final isDashboardHome = location == '/dashboard';

    final shellContent = MediaQuery.removePadding(
      context: context,
      removeTop: false,
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
      canPop: !branchCanPop,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && branchCanPop) {
          AppRouter.branchKeys[currentIndex].currentState?.pop();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        resizeToAvoidBottomInset: false,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // PERFORMANCE-01: Aislamos el wallpaper y el fluido liquido en un RepaintBoundary
            // independiente. Que hace: confina el CustomPainter continuo a su propia textura GPU.
            // Como funciona: el rasterizer no repinta el indexedStack ni la barra de navegacion en cada frame.
            // Por que: elimina el jank y sobrecarga de GPU durante el cambio de pantalla.
            Positioned.fill(
              child: RepaintBoundary(
                child: BuhoWallpaper(
                  scrimOpacity: isDark ? 0.45 : 0.22,
                ),
              ),
            ),
            // DOCK-FLOAT-01: floatOverContent en true garantiza que la pantalla hija
            // pinte a altura completa sin franjas cortadas. La barra flota encima
            // con su efecto translúcido liquid glass sobre el fondo continuo.
            NanoFloatingNavigationFrame(
              allowSideDock: true,
              selectedIndex: currentIndex,
              fullBleed: false,
              floatOverContent: true,
              transparentDock: true,
              protectTop: !isDashboardHome,
              onDestinationSelected: (index) {
                if (index == _automationShortcutIndex) {
                  context.push('/automation');
                  return;
                }
                shell.goBranch(index, initialLocation: index == currentIndex);
              },
              child: boundedContent,
            ),
          ],
        ),
      ),
    );
  }
}
