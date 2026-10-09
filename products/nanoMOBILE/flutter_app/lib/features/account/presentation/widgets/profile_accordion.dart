import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../../core/theme/design_tokens.dart';

/// Etiqueta de sección editorial estilo iOS Glass con tipografía overline.
class ProfileSectionLabel extends StatelessWidget {
  final String label;
  final NanoColors colors;
  const ProfileSectionLabel({super.key, required this.label, required this.colors});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
        child: Text(
          label.toUpperCase(),
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1,
            color: colors.onSurfaceVariant.withValues(alpha: 0.80),
          ),
        ),
      );
}

/// Acordeón de edición estilo iOS Grouped Frosted Glass Tile.
class ProfileEditAccordion extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget child;
  final NanoColors colors;
  final Color? iconColor;

  const ProfileEditAccordion({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.child,
    required this.colors,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveIconColor = iconColor ?? colors.primary;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            decoration: BoxDecoration(
              color: colors.surface.withValues(alpha: 0.70),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: colors.outlineVariant.withValues(alpha: 0.45),
                width: 0.85,
              ),
              boxShadow: [
                BoxShadow(
                  color: colors.onSurface.withValues(alpha: 0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
                expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: effectiveIconColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: effectiveIconColor.withValues(alpha: 0.25),
                      width: 0.6,
                    ),
                  ),
                  child: Icon(icon, size: 18, color: effectiveIconColor),
                ),
                title: Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: colors.onSurface,
                  ),
                ),
                subtitle: subtitle != null
                    ? Text(
                        subtitle!,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11,
                          color: colors.onSurfaceVariant,
                        ),
                      )
                    : null,
                iconColor: colors.onSurfaceVariant,
                collapsedIconColor: colors.onSurfaceVariant,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(16)),
                ),
                collapsedShape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(16)),
                ),
                children: [
                  const SizedBox(height: 6),
                  child,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
