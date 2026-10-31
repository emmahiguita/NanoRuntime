part of 'account_settings_card.dart';

/// Perfil sin sesi?n: navegaci?n real a registro y acceso.
class _UnauthenticatedProfileCard extends StatelessWidget {
  final NanoColors colors;
  const _UnauthenticatedProfileCard({required this.colors});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: AutomationSurfaceCard(
        radius: 20,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        onTap: () => context.push('/auth/login'),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: isDark
                    ? colors.surfaceVariant.withValues(alpha: 0.5)
                    : colors.surface,
                shape: BoxShape.circle,
                border: Border.all(
                  color: colors.outlineVariant.withValues(alpha: isDark ? 0.35 : 0.50),
                  width: 1.0,
                ),
              ),
              child: Icon(
                Icons.person_rounded,
                color: colors.onSurfaceVariant,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Perfil Soberano Nano',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                      fontSize: 15.5,
                      letterSpacing: -0.2,
                      color: colors.onSurface,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Identidad local, privacidad y modelos fuera de línea.',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: colors.onSurfaceVariant,
                      decoration: TextDecoration.none,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: colors.onSurfaceVariant.withValues(alpha: 0.6),
            ),
          ],
        ),
      ),
    );
  }
}
