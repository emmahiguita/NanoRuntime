import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../theme/design_tokens.dart';
import '../providers/chat_provider.dart';
import '../router/app_router.dart';
import '../theme/nano_breakpoint.dart';
import '../widgets/navigation/nano_navigation_panel.dart';
import '../../features/home/buho_wallpaper.dart';
import '../../features/chat/nano_everywhere/nano_floating_wrapper.dart';
import '../../features/chat/nano_everywhere/nano_providers.dart';

/// Shell principal: conserva los stacks de cada pestaña y separa el área
/// de navegación inferior y barra de búsqueda/escritura del contenido scrolleable.
class ScaffoldShell extends ConsumerWidget {
  const ScaffoldShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = shell.currentIndex;
    final branchCanPop =
        AppRouter.branchKeys[currentIndex].currentState?.canPop() ?? false;
    final shellColors = Theme.of(
      context,
    ).extension<NanoThemeExtension>()!.colors;
    final isDark = shellColors is NanoDarkColors;

    final location = GoRouterState.of(context).matchedLocation;
    final isDashboardHome =
        location == '/dashboard' || location == '/automation';
    final isBrowser = location.startsWith('/browser');

    final webProviders = ref.watch(nanoWebProvidersProvider);
    final actionPort = ref.watch(nanoActionPortProvider);
    final audioLevel = ref.watch(nanoAudioLevelProvider);
    final navState = ref.watch(nanoNavModeProvider);

    final shellContent = Builder(
      builder: (viewportContext) => MediaQuery.removePadding(
        context: viewportContext,
        removeTop: false,
        removeBottom: true,
        removeLeft: true,
        removeRight: true,
        child: shell,
      ),
    );
    final boundedContent = Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: NanoBreakpoints.contentMaxWidth,
        ),
        child: shellContent,
      ),
    );

    final returnsHome = !branchCanPop && currentIndex != 0;

    return PopScope(
      canPop: !branchCanPop &&
          !returnsHome &&
          !navState.isDrawerOpen &&
          !navState.isFabMenuOpen,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (navState.isFabMenuOpen) {
          ref.read(nanoNavModeProvider.notifier).closeFabMenu();
          return;
        }
        if (navState.isDrawerOpen) {
          ref.read(nanoNavModeProvider.notifier).closeDrawer();
          return;
        }
        if (branchCanPop) {
          AppRouter.branchKeys[currentIndex].currentState?.pop();
        } else if (returnsHome) {
          shell.goBranch(0);
        }
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        resizeToAvoidBottomInset: false,
        body: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: RepaintBoundary(
                child: BuhoWallpaper(scrimOpacity: isDark ? 0.45 : 0.22),
              ),
            ),
            NanoFloatingNavigationFrame(
              allowSideDock: true,
              selectedIndex: currentIndex,
              fullBleed: false,
              // Reserva el espacio medido del dock para mantener accesible el contenido.
              floatOverContent: true,
              transparentDock: true,
              protectTop: !isDashboardHome,
              onDestinationSelected: (index) {
                shell.goBranch(index, initialLocation: index == currentIndex);
              },
              child: NanoFloatingWrapper(
                enabled: !isBrowser,
                webProviders: webProviders,
                actions: actionPort,
                audioLevel: audioLevel,
                voiceSession: ref.read(chatProvider.notifier).voiceSession,
                child: boundedContent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
