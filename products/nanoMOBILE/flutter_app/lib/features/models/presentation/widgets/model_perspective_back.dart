// model_perspective_back.dart — Componentes auxiliares para tarjeta 3D de modelos.
// QUÉ HACE: Despliega especificaciones en el reverso y badges compactos para el anverso.
// CÓMO FUNCIONA: Widgets sin estado desacoplados con diseño Material Expressive.
// POR QUÉ: Extrae elementos visuales para garantizar que cada archivo tenga < 200 líneas.
library;

import 'package:flutter/material.dart';
import '../../../../core/theme/design_tokens.dart';
import 'model_catalog_types.dart';

class ModelPerspectiveBack extends StatelessWidget {
  final UnifiedModelItem item;
  final VoidCallback onFlipBack;

  const ModelPerspectiveBack({
    super.key,
    required this.item,
    required this.onFlipBack,
  });

  @override
  Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;
    final isDark = colors is NanoDarkColors;

    return Material(
      color: isDark ? const Color(0xFF131C30) : colors.surfaceVariant,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: colors.primary.withValues(alpha: 0.4),
          width: 1.2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.memory_rounded, size: 16, color: colors.primary),
                const SizedBox(width: 6),
                Text(
                  'DETALLE TÉCNICO',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: colors.primary,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Volver al anverso',
                  onPressed: onFlipBack,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              item.fileName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: colors.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              item.catalog?.description ?? 'Modelo local en almacenamiento.',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ModelTagBadge extends StatelessWidget {
  final String label;
  final Color color;

  const ModelTagBadge({super.key, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 8.5,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
