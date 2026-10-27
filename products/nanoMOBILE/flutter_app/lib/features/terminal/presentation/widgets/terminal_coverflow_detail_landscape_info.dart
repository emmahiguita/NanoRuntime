part of 'terminal_coverflow_card.dart';

/// Ficha de terminal: detail landscape info; conserva navegación y tema.
extension _TerminalLandscapeInfo on TerminalHubDetailCard {
  Widget _landscapeInformation(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;
    final isDark = colors is NanoDarkColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          card.title,
          style: TextStyle(
            fontFamily: 'Inter',
            color: colors.textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.6,
          ),
        ),
        const SizedBox(height: 3),
        Row(
          children: [
            Icon(card.icon, size: 13, color: card.accent),
            const SizedBox(width: 6),
            Text(
              '${card.eyebrow} • 2026',
              style: TextStyle(
                fontFamily: 'Inter',
                color: colors.textSecondary,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          card.description,
          style: TextStyle(
            fontFamily: 'Inter',
            color: colors.textSecondary,
            fontSize: 12.5,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 10),
        for (final highlight in card.highlights)
          Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.check_circle_rounded, size: 13, color: card.accent),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    highlight,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      color: colors.textPrimary,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 44,
          child: FilledButton.icon(
            onPressed: () {
              final router = GoRouter.of(context);
              Navigator.of(context, rootNavigator: true).pop();
              router.push(card.route);
            },
            icon: const Icon(Icons.play_arrow_rounded, size: 20),
            label: Text(
              card.actionLabel,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: colors.onAccent,
              ),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: card.accent,
              foregroundColor: colors.onAccent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
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
