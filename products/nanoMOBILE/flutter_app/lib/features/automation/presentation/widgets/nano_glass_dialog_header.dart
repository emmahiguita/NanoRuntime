import 'package:flutter/material.dart';

/// Cabecera compartida: título adaptable y cierre del diálogo que la contiene.
class NanoGlassDialogHeader extends StatelessWidget {
  const NanoGlassDialogHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.iconColor,
    this.onClose,
  });
  final String title;
  final String? subtitle;
  final IconData? icon;
  final Color? iconColor;
  final VoidCallback? onClose;

  // Expanded permite títulos largos sin desplazar el botón de cierre.
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        if (icon != null) ...[
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (iconColor ?? const Color(0xFF2563EB)).withValues(
                alpha: 0.15,
              ),
              shape: BoxShape.circle,
              border: Border.all(
                color: (iconColor ?? const Color(0xFF2563EB)).withValues(
                  alpha: 0.30,
                ),
                width: 0.8,
              ),
            ),
            child: Icon(
              icon,
              size: 18,
              color:
                  iconColor ??
                  (isDark ? Colors.white : const Color(0xFF2563EB)),
            ),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  letterSpacing: -0.2,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white60 : const Color(0xFF64748B),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (onClose != null)
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: Icon(
              Icons.close_rounded,
              size: 20,
              color: isDark ? Colors.white54 : const Color(0xFF94A3B8),
            ),
            onPressed: onClose,
          ),
      ],
    );
  }
}
