part of 'terminal_coverflow_card.dart';

/// Ficha de terminal: detail landscape; conserva navegación y tema.
extension _TerminalLandscape on TerminalHubDetailCard {
  Widget _landscape(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;
    final isDark = colors is NanoDarkColors;

    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Columna Izquierda: Visor 3D Turntable Box centrado
              Expanded(
                flex: 4,
                child: Center(
                  child: _MotionAwareTerminalBox(
                    card: card,
                    width: 145,
                    height: 205,
                    depth: 22,
                  ),
                ),
              ),
              const SizedBox(width: 18),
              // Columna Derecha: Información y botón de ejecución
              Expanded(
                flex: 6,
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.only(top: 8, bottom: 8, right: 8),
                  child: _landscapeInformation(context),
                ),
              ),
            ],
          ),
        ),
        Positioned(
          top: 6,
          right: 6,
          child: ClipOval(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.15)
                      : colors.surface.withValues(alpha: 0.90),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.20)
                        : colors.borderSecondaryColor,
                  ),
                ),
                child: IconButton(
                  padding: EdgeInsets.zero,
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(
                    Icons.close_rounded,
                    color: isDark ? Colors.white : colors.textPrimary,
                    size: 18,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
