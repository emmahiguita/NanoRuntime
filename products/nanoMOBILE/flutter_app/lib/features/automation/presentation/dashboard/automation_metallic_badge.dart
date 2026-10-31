import 'package:flutter/material.dart';

/// Reutiliza simbolos Nano en una superficie compacta y adaptable al tema.
class AutomationMetallicBadge extends StatelessWidget {
  const AutomationMetallicBadge({
    super.key,
    required this.icon,
    required this.badgeGradient,
    required this.specularColor,
    required this.isDark,
    required this.neutral,
  });
  final Widget icon;
  final Gradient badgeGradient;
  final Color specularColor;
  final bool isDark, neutral;

  /// grafito; Claro y Gris espacial conservan sus gradientes originales.
  @override
  Widget build(BuildContext context) {
    final reflection = neutral ? const Color(0xFFB9B9BF) : specularColor;
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(13),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.90),
            reflection.withValues(alpha: 0.60),
            Colors.white.withValues(alpha: 0.20),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: reflection.withValues(alpha: 0.18),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(1.2),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: neutral
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF38383C), Color(0xFF161618)],
                )
              : badgeGradient,
        ),
        child: Center(child: icon),
      ),
    );
  }
}
