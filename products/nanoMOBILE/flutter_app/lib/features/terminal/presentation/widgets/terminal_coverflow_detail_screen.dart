part of 'terminal_coverflow_card.dart';

/// Ficha de terminal: detail screen; conserva navegación y tema.
class TerminalHubDetailScreen extends StatelessWidget {
  const TerminalHubDetailScreen({super.key, required this.card});

  final TerminalHubCard card;

  static void show(BuildContext context, TerminalHubCard card) {
    final capturedThemes = InheritedTheme.capture(
      from: context,
      to: Navigator.of(context, rootNavigator: true).context,
    );

    Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: Colors.transparent,
        transitionDuration: const Duration(milliseconds: 520),
        reverseTransitionDuration: const Duration(milliseconds: 420),
        pageBuilder: (context, animation, secondaryAnimation) {
          return capturedThemes.wrap(TerminalHubDetailScreen(card: card));
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            ),
            child: child,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Size screen = MediaQuery.sizeOf(context);
    final bool isLandscape =
        screen.width > screen.height && screen.height < 550;
    final double width = isLandscape
        ? math.min(screen.width * 0.92, 780.0)
        : math.min(screen.width, 500.0);
    final colors = NanoThemeExtension.of(context).colors;
    final isDark = colors is NanoDarkColors;

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          // Fondo cinematográfico con el wallpaper del Búho y desenfoque de cristal óptico
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.pop(context),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const BuhoWallpaper(scrimOpacity: 0.35),
                  BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                    child: ColoredBox(
                      color: isDark
                          ? Colors.black.withValues(alpha: 0.55)
                          : colors.surface.withValues(alpha: 0.65),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Contenido principal de la ficha
          SafeArea(
            child: Center(
              child: SizedBox(
                width: width,
                height: screen.height,
                child: Hero(
                  tag: 'terminal-card-${card.id}',
                  createRectTween: (begin, end) {
                    return MaterialRectCenterArcTween(begin: begin, end: end);
                  },
                  flightShuttleBuilder: perspectiveHeroFlight,
                  child: Material(
                    color: Colors.transparent,
                    child: TerminalHubDetailCard(card: card),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Ficha completa con Visor 3D y sección de información.
