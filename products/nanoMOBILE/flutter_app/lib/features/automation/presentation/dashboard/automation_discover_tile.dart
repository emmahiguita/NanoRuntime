// automation_discover_tile.dart — Tarjeta de capacidad estilo Apple iOS Metallic Glass.
//
// QUÉ HACE:
// Renderiza cada tarjeta de herramienta clave de Nano AI con estética de cristal líquido y badge metálico.
//
// CÓMO FUNCIONA:
// - Construye un badge con gradiente vibrante, borde especular brillante (luz en top-left) y sombra suave.
// - Aplica micro-interacción háptica al tocar y tipografía SF Pro / Inter de alto contraste.
//
// POR QUÉ:
// Ofrece una presencia visual premium y uniforme en el dashboard de automatización (< 150 líneas).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../automation_visual_theme.dart';

class AutomationDiscoverTile extends StatelessWidget {
  final AutomationVisualPalette visual;
  final String category;
  final String title;
  final String description;
  final Gradient badgeGradient;
  final Color specularColor;
  final IconData icon;
  final VoidCallback? onTap;

  const AutomationDiscoverTile({
    super.key,
    required this.visual,
    required this.category,
    required this.title,
    required this.description,
    required this.badgeGradient,
    required this.specularColor,
    required this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = visual.isDark;

    return Semantics(
      button: onTap != null,
      enabled: onTap != null,
      label: '$title. $category. $description',
      child: AutomationSurfaceCard(
        radius: 20,
        blurSigma: 16,
        padding: const EdgeInsets.all(14),
        onTap: onTap == null
            ? null
            : () {
                HapticFeedback.lightImpact();
                onTap!();
              },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // 1. Badge con acabado metálico líquido iOS
            _buildMetallicBadge(isDark),
            const SizedBox(height: 12),

            // 2. Categoría sutil
            Text(
              category,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: visual.textMuted.withValues(alpha: 0.88),
                letterSpacing: 0.35,
              ),
            ),
            const SizedBox(height: 3),

            // 3. Título principal
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: visual.text,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 4),

            // 4. Descripción breve
            Text(
              description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 11.5,
                color: visual.textMuted,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetallicBadge(bool isDark) {
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
            specularColor.withValues(alpha: 0.60),
            Colors.white.withValues(alpha: 0.20),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: specularColor.withValues(alpha: isDark ? 0.30 : 0.18),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(1.2),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: badgeGradient,
        ),
        child: Center(
          child: Icon(
            icon,
            size: 20,
            color: Colors.white,
            shadows: const [
              Shadow(
                color: Colors.black26,
                blurRadius: 4,
                offset: Offset(0, 1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
