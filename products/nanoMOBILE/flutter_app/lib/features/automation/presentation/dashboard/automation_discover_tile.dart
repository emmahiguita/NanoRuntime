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
import '../../../../core/theme/design_tokens.dart';

import '../automation_visual_theme.dart';
import 'automation_metallic_badge.dart';

class AutomationDiscoverTile extends StatelessWidget {
  final AutomationVisualPalette visual;
  final String category;
  final String title;
  final String description;
  final Gradient badgeGradient;
  final Color specularColor;
  final Widget icon;
  final VoidCallback? onTap;
  final bool horizontal;

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
    this.horizontal = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = visual.isDark;
    final neutral = NanoPaletteBrightness.isBlack(visual.resolvedColors);

    return Semantics(
      button: onTap != null,
      enabled: onTap != null,
      label: '$title. $category. $description',
      child: AutomationSurfaceCard(
        // El negro comparte los materiales del tema; no añade un tinte azul.
        surfaceTint: neutral ? null : (isDark ? const Color(0xC0143970) : null),
        radius: 20,
        blurSigma: 16,
        padding: const EdgeInsets.all(14),
        onTap: onTap == null
            ? null
            : () {
                HapticFeedback.lightImpact();
                onTap!();
              },
        child: horizontal
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AutomationMetallicBadge(
                    icon: icon,
                    badgeGradient: badgeGradient,
                    specularColor: specularColor,
                    isDark: isDark,
                    neutral: neutral,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          category,
                          style: TextStyle(
                            color: visual.textMuted,
                            fontSize: 10.5,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          title,
                          style: TextStyle(
                            color: visual.text,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: visual.textMuted,
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 1. Badge con acabado metálico líquido iOS
                  AutomationMetallicBadge(
                    icon: icon,
                    badgeGradient: badgeGradient,
                    specularColor: specularColor,
                    isDark: isDark,
                    neutral: neutral,
                  ),
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

  /// Mantiene la forma y el símbolo de cada acción. En Oscuro usa cristal
}
