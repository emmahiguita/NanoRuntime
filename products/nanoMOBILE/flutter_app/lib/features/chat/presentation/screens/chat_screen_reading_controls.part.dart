part of 'chat_screen.dart';

/// Barra de progreso de lectura: refleja la fracción de scroll de forma sutil.
class _ReadingProgress extends StatelessWidget {
  const _ReadingProgress({required this.scroll});

  final ScrollController scroll;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: scroll,
      builder: (context, _) {
        final colors = Theme.of(
          context,
        ).extension<NanoThemeExtension>()!.colors;
        final pos = scroll.hasClients ? scroll.position : null;
        if (pos == null || !pos.hasViewportDimension) {
          return const SizedBox(height: 2.5);
        }
        final max = pos.maxScrollExtent;
        final frac = max <= 0 ? 1.0 : (pos.pixels / max).clamp(0.0, 1.0);

        return Container(
          height: 2.5,
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: frac,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [colors.accent, colors.accentCyan],
                ),
                borderRadius: BorderRadius.circular(3),
                boxShadow: [
                  BoxShadow(
                    color: colors.accent.withValues(alpha: 0.45),
                    blurRadius: 6,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Píldora de vidrio para salir del modo lectura (con texto, no solo icono).
class _ReadingExitPill extends StatelessWidget {
  const _ReadingExitPill({required this.onExit});

  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<NanoThemeExtension>()!.colors;
    return NanoOpticalSurface(
      key: const ValueKey('chat_reading_mode_exit'),
      geometry: NanoSurfaceGeometry.capsule,
      borderRadius: 999,
      blurSigma: 14,
      borderStrength: 0.62,
      reflectionStrength: 0.50,
      accent: colors.accent,
      onTap: onExit,
      padding: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.fullscreen_exit_rounded,
              size: 15,
              color: colors.onSurface.withValues(alpha: 0.75),
            ),
            const SizedBox(width: 5),
            Text(
              'Salir de lectura',
              style: TextStyle(
                color: colors.onSurface.withValues(alpha: 0.80),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
