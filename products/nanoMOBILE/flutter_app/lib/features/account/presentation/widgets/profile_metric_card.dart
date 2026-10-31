import 'package:flutter/material.dart';
import '../../../../core/theme/design_tokens.dart';

/// Tarjeta métrica estilo iOS Inset Tile sobria y profesional.
class ProfileMetricCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? statusText;
  final VoidCallback? onTap;

  const ProfileMetricCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.statusText,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final themeExt = NanoThemeExtension.maybeOf(context);
    final colors = themeExt?.colors ?? const NanoDarkColors();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
            decoration: BoxDecoration(
              color: isDark
                  ? colors.surfaceVariant.withValues(alpha: 0.35)
                  : colors.surface.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: colors.outlineVariant.withValues(alpha: isDark ? 0.30 : 0.45),
                width: 0.8,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Icon(icon, size: 15, color: colors.onSurfaceVariant),
                    if (statusText != null)
                      Text(
                        statusText!,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: colors.onSurfaceVariant,
                          decoration: TextDecoration.none,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  value,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                    color: colors.onSurface,
                    letterSpacing: -0.2,
                    decoration: TextDecoration.none,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 1),
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
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
        ),
      ),
    );
  }
}
