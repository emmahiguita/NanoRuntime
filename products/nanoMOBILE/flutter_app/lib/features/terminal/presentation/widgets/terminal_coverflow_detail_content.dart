part of 'terminal_coverflow_card.dart';

/// Ficha de terminal: detail content; conserva navegación y tema.
extension _TerminalContent on TerminalHubDetailCard {
  Widget _portraitContent(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;
    final isDark = colors is NanoDarkColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // -------------------------------------------------------------
        // 5. PÁRRAFO DE DESCRIPCIÓN COMPLETA
        // -------------------------------------------------------------
        Text(
          card.description,
          style: TextStyle(
            fontFamily: 'Inter',
            color: colors.textSecondary,
            fontSize: 14,
            height: 1.5,
          ),
        ),

        const SizedBox(height: 18),

        // -------------------------------------------------------------
        // 6. CAPACIDADES INTEGRADAS
        // -------------------------------------------------------------
        Text(
          'CAPACIDADES INTEGRADAS',
          style: TextStyle(
            fontFamily: 'Inter',
            color: NanoTextColors.forText(card.accent, colors),
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 10),
        for (final highlight in card.highlights)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.check_circle_rounded, size: 16, color: card.accent),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    highlight,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      color: colors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

        const SizedBox(height: 24),

        // -------------------------------------------------------------
        // 7. BOTÓN DE ACCIÓN / EJECUCIÓN DIRECTA
        // -------------------------------------------------------------
        SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton.icon(
            onPressed: () {
              final router = GoRouter.of(context);
              Navigator.of(context, rootNavigator: true).pop();
              router.push(card.route);
            },
            icon: const Icon(Icons.play_arrow_rounded, size: 22),
            label: Text(
              card.actionLabel,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 15.5,
                fontWeight: FontWeight.w800,
                color: colors.onAccent,
              ),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: card.accent,
              foregroundColor: colors.onAccent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: isDark ? 4 : 2,
              shadowColor: card.accent.withValues(alpha: 0.35),
            ),
          ),
        ),
      ],
    );
  }
}
