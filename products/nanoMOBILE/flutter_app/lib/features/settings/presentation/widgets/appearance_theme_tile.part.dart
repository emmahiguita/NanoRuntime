part of 'appearance_settings_card.dart';

/// Botón interactivo táctil de opción de tema estilo iOS Segmented Item sobrio.
class _ThemeTile extends StatelessWidget {
  final String id, sublabel;
  final IconData icon;
  final bool isSelected, isCompact;
  final NanoColors colors;
  final VoidCallback onTap;

  const _ThemeTile({
    required this.id,
    required this.sublabel,
    required this.icon,
    required this.isSelected,
    required this.isCompact,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeBg = isDark
        ? colors.surfaceVariant.withValues(alpha: 0.80)
        : colors.surface;
    final inactiveBg = isDark
        ? colors.surfaceVariant.withValues(alpha: 0.25)
        : colors.backgroundElevated.withValues(alpha: 0.50);
    final borderColor = isSelected
        ? colors.primary.withValues(alpha: 0.45)
        : colors.outlineVariant.withValues(alpha: isDark ? 0.20 : 0.35);
    final tint = isSelected ? colors.primary : colors.onSurfaceVariant;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        splashColor: colors.primary.withValues(alpha: 0.08),
        highlightColor: colors.primary.withValues(alpha: 0.04),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
          decoration: BoxDecoration(
            color: isSelected ? activeBg : inactiveBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: borderColor,
              width: isSelected ? 1.0 : 0.7,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: colors.onSurface.withValues(alpha: 0.04),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: tint),
              const SizedBox(height: 4),
              Text(
                id,
                style: TextStyle(
                  fontFamily: 'Inter',
                  color: isSelected ? colors.primary : colors.onSurface,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  fontSize: 11.5,
                  decoration: TextDecoration.none,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (!isCompact) ...[
                const SizedBox(height: 1),
                Text(
                  sublabel,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    color: isSelected
                        ? colors.primary.withValues(alpha: 0.85)
                        : colors.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                    fontSize: 11,
                    decoration: TextDecoration.none,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
