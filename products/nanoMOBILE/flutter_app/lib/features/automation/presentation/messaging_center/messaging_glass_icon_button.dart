import 'package:flutter/material.dart';

/// QUÉ HACE: Botón táctil con efecto de vidrio esmerilado translúcido iOS.
/// CÓMO FUNCIONA: Usa Semantics en vez de Tooltip para evitar el error "No Overlay".
/// POR QUÉ: Tooltip requiere Overlay ancestor, fallando dentro de Hero o Layouts aislados.
class IosGlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final String? tooltip;
  final double size, iconSize;
  final Color? iconColor;

  const IosGlassIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.onLongPress,
    this.tooltip,
    this.size = 32,
    this.iconSize = 16,
    this.iconColor,
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
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF1E293B).withValues(alpha: 0.48)
                : Colors.white.withValues(alpha: 0.45),
            shape: BoxShape.circle,
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.15)
                  : Colors.white.withValues(alpha: 0.66),
              width: 1.1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
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
      ),
    );
    return tooltip != null
        ? Semantics(label: tooltip, button: true, child: button)
        : button;
  }
}
