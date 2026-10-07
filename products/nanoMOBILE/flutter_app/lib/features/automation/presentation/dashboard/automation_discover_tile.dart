// automation_discover_tile.dart — Tarjeta en cuadrícula 2x2 para capacidades nucleares de Nano AI.
// QUÉ HACE: Renderiza una tarjeta estilo Material 3 Expressive con badge colorido, categoría, título y descripción.
// CÓMO FUNCIONA: Usa Container Liquid-Glass con badge orgánico superior, tipografía jerárquica y tap táctil háptico.
// POR QUÉ: Adapta la sección "Descubre más sobre Nano" al formato de cuadrícula 2x2 solicitado (< 200 líneas).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../automation_visual_theme.dart';

/// Tarjeta de cuadrícula con badge superior, etiqueta de categoría, título y resumen.
class AutomationDiscoverTile extends StatelessWidget {
  final AutomationVisualPalette visual;
  final String category;
  final String title;
  final String description;
  final Color badgeColor;
  final Gradient? badgeGradient;
  final BorderRadius? badgeBorderRadius;
  final IconData icon;
  final VoidCallback? onTap;

  const AutomationDiscoverTile({
    super.key,
    required this.visual,
    required this.category,
    required this.title,
    required this.description,
    required this.badgeColor,
    required this.icon,
    this.badgeGradient,
    this.badgeBorderRadius,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Semantics(
      button: true,
      label: '$title. $category. $description',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap?.call();
          },
          borderRadius: BorderRadius.circular(20),
          splashColor: badgeColor.withValues(alpha: 0.15),
          highlightColor: badgeColor.withValues(alpha: 0.08),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark
                  ? visual.surface.withValues(alpha: 0.65)
                  : visual.surface.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark
                    ? visual.outline.withValues(alpha: 0.18)
                    : visual.outline.withValues(alpha: 0.10),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // 1. Icono superior unificado en contenedor sobrio
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: visual.accentSoft,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: visual.accent.withValues(alpha: isDark ? 0.32 : 0.22),
                      width: 1,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    icon,
                    size: 20,
                    color: visual.accent,
                  ),
                ),
                const SizedBox(height: 12),

                // 2. Etiqueta / Categoría (jerarquía secundaria limpia)
                Text(
                  category,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: visual.textMuted.withValues(alpha: 0.85),
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 3),

                // 3. Título principal en negrita
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 15.0,
                    fontWeight: FontWeight.w700,
                    color: visual.text,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 4),

                // 4. Descripción breve de la función
                Text(
                  description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11.5,
                    fontWeight: FontWeight.w400,
                    color: visual.textMuted,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
