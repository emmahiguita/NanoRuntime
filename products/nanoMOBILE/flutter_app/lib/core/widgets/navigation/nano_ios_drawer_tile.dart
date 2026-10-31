// nano_ios_drawer_tile.dart — Celda de navegación estilo iOS Inset Grouped.
// QUÉ HACE: Renderiza un elemento de lista con badge squircle, tipografía Inter y chevron.
// CÓMO FUNCIONA: Usa InkWell con feedback háptico, badge semántico y divisor inferior con inset.
// POR QUÉ: Diseño 100% iOS limpio y profesional, modular y estrictamente < 200 líneas.
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class NanoIosDrawerTile extends StatelessWidget {
  const NanoIosDrawerTile({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    this.subtitle,
    this.badgeText,
    this.isSelected = false,
    this.showDivider = true,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final String? badgeText;
  final bool isSelected;
  final bool showDivider;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final selectedBg = isDark
        ? scheme.primary.withValues(alpha: 0.16)
        : scheme.primary.withValues(alpha: 0.08);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: isSelected ? selectedBg : Colors.transparent,
          child: InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              onTap();
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8.5),
              child: Row(
                children: [
                  // 1. Squircle icon badge estilo iOS
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: iconColor,
                      borderRadius: BorderRadius.circular(7.5),
                      boxShadow: [
                        BoxShadow(
                          color: iconColor.withValues(alpha: isDark ? 0.35 : 0.25),
                          blurRadius: 4,
                          offset: const Offset(0, 1.5),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Icon(icon, color: Colors.white, size: 16),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // 2. Título y subtítulo
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13.5,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                            letterSpacing: -0.2,
                            color: isSelected ? scheme.primary : scheme.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 1),
                          Text(
                            subtitle!,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 11,
                              fontWeight: FontWeight.w400,
                              color: scheme.onSurfaceVariant.withValues(alpha: 0.75),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  // 3. Badge o indicador de estado opcional
                  if (badgeText != null)
                    Container(
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 6.5, vertical: 2),
                      decoration: BoxDecoration(
                        color: isDark
                            ? scheme.primary.withValues(alpha: 0.20)
                            : scheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        badgeText!,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: scheme.primary,
                        ),
                      ),
                    ),
                  // 4. Chevron iOS
                  Icon(
                    CupertinoIcons.chevron_right,
                    size: 13,
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.45),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (showDivider)
          Padding(
            padding: const EdgeInsets.only(left: 56, right: 14),
            child: Divider(
              height: 0.5,
              thickness: 0.5,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.06),
            ),
          ),
      ],
    );
  }
}
