part of 'terminal_coverflow_card.dart';

/// Ficha de terminal: detail portrait; conserva navegación y tema.
extension _TerminalPortrait on TerminalHubDetailCard {
  Widget _portrait(BuildContext context, bool isCompact) {
    final colors = NanoThemeExtension.of(context).colors;
    final isDark = colors is NanoDarkColors;

    return Stack(
      children: [
        // Contenido con scroll vertical
        SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            22,
            isCompact ? 16 : 48,
            22,
            isCompact ? 20 : 36,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _portraitHeading(context, isCompact),
              _portraitTags(context),
              _portraitContent(context),
            ],
          ),
        ),

        // -------------------------------------------------------------------
        // BOTÓN SUPERIOR DERECHO: 'X' (CERRAR)
        // -------------------------------------------------------------------
        Positioned(
          top: 10,
          right: 10,
          child: ClipOval(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Container(
                width: 40,
                height: 40,
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
                    size: 20,
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
