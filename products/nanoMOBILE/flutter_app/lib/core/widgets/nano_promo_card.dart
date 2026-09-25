import 'package:flutter/material.dart';

/// Tarjeta de contenido patrocinado, promocional o de crecimiento comercial.
///
/// Diseñada con estética seria y profesional (Cards as Heroes):
/// - Alto contraste con el fondo neutro OLED/Slate.
/// - Insignia sutil (Destacado / Patrocinado / Oportunidad) para transparencia.
/// - Soporte para botón de acción rápido y descarte respetuoso (sin dark patterns).
/// - Rendimiento ultra ligero (cero shaders continuos o bucles de GPU).
class NanoPromoCard extends StatelessWidget {
  final String title;
  final String description;
  final String badgeText;
  final Color? badgeColor;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onActionTap;
  final VoidCallback? onDismiss;

  const NanoPromoCard({
    super.key,
    required this.title,
    required this.description,
    this.badgeText = 'DESTACADO',
    this.badgeColor,
    this.icon = Icons.auto_awesome_rounded,
    this.actionLabel,
    this.onActionTap,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final accent = badgeColor ?? (dark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7));

    final cardBg = dark ? const Color(0xFF13151D) : Colors.white;
    final borderColor = dark ? const Color(0xFF232736) : const Color(0xFFE2E8F0);
    final titleColor = dark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
    final descColor = dark ? const Color(0xFF94A3B8) : const Color(0xFF475569);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: dark ? Colors.black.withValues(alpha: 0.35) : const Color(0x0A000000),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onActionTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: accent.withValues(alpha: 0.35),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(icon, size: 12, color: accent),
                          const SizedBox(width: 4),
                          Text(
                            badgeText.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.6,
                              color: accent,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    if (onDismiss != null)
                      GestureDetector(
                        onTap: onDismiss,
                        behavior: HitTestBehavior.opaque,
                        child: Padding(
                          padding: const EdgeInsets.all(2),
                          child: Icon(
                            Icons.close_rounded,
                            size: 16,
                            color: descColor.withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: titleColor,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 13,
                    color: descColor,
                    height: 1.4,
                  ),
                ),
                if (actionLabel != null && onActionTap != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        actionLabel!,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: accent,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.arrow_forward_rounded, size: 14, color: accent),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
