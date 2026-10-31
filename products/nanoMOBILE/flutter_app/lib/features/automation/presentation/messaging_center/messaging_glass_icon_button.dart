// messaging_glass_icon_button.dart
// QUÉ HACE: Botón táctil con efecto de vidrio esmerilado translúcido iOS y área táctil accesible.
// CÓMO FUNCIONA: Visual 34dp centrado en área táctil 44x44 dp, con soporte para badge de conexión.
// POR QUÉ: Cumple pautas de accesibilidad (área táctil >= 44dp) y diseño iOS Liquid Glass (< 95 líneas).
library;

import 'package:flutter/material.dart';

class IosGlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final String? tooltip;
  final double size, iconSize;
  final Color? iconColor;
  final bool hasBadge;
  final Color? badgeColor;

  const IosGlassIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.onLongPress,
    this.tooltip,
    this.size = 34,
    this.iconSize = 17,
    this.iconColor,
    this.hasBadge = false,
    this.badgeColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultIconColor =
        isDark ? Colors.white70 : const Color(0xFF334155);

    final button = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(size / 2),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1E293B).withValues(alpha: 0.55)
                      : Colors.white.withValues(alpha: 0.60),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.16)
                        : Colors.white.withValues(alpha: 0.75),
                    width: 1.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.30 : 0.06),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(
                    icon,
                    size: iconSize,
                    color: iconColor ?? defaultIconColor,
                  ),
                ),
              ),
              if (hasBadge)
                Positioned(
                  top: 5,
                  right: 5,
                  child: Container(
                    width: 7.5,
                    height: 7.5,
                    decoration: BoxDecoration(
                      color: badgeColor ?? const Color(0xFF10B981),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDark ? const Color(0xFF0F172A) : Colors.white,
                        width: 1.2,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    return tooltip != null
        ? Semantics(label: tooltip, button: true, child: button)
        : button;
  }
}
