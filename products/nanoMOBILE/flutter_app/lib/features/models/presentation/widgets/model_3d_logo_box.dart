// model_3d_logo_box.dart — Cuadro de portada tridimensional para modelos neurales.
// QUÉ HACE: Renderiza el contenedor físico cuadrado con logo de marca, bisel y reflejo especular.
// CÓMO FUNCIONA: Apila gradiente de profundidad, borde de iluminación y reflejo de luz diagonal.
// POR QUÉ: Otorga identidad visual táctil inspirada en el módulo de Terminal (< 130 líneas).
library;

import 'package:flutter/material.dart';
import '../../../../core/theme/design_tokens.dart';
import 'model_brand_logo.dart';
import 'model_catalog_types.dart';

class Model3DLogoBox extends StatelessWidget {
  final UnifiedModelItem item;
  final double size;

  const Model3DLogoBox({
    super.key,
    required this.item,
    this.size = 64,
  });

  @override
  Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;
    final isDark = colors is NanoDarkColors;

    // Resuelve el color de acento según la familia del modelo
    final brandColor = _resolveAccentColor(item);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0D131F) : colors.surface,
        borderRadius: BorderRadius.circular(size * 0.24),
        border: Border.all(
          color: isDark
              ? brandColor.withValues(alpha: 0.35)
              : brandColor.withValues(alpha: 0.25),
          width: 1.6,
        ),
        boxShadow: [
          // Sombra de oclusión ambiental
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
          // Resplandor de acento de marca
          BoxShadow(
            color: brandColor.withValues(alpha: 0.20),
            blurRadius: 14,
            spreadRadius: -1,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.22),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Fondo con gradiente de profundidad
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? [
                          brandColor.withValues(alpha: 0.18),
                          const Color(0xFF050811),
                        ]
                      : [
                          colors.surface,
                          brandColor.withValues(alpha: 0.12),
                        ],
                ),
              ),
            ),

            // Logo centrado con escala proporcional
            Center(
              child: ModelBrandLogo(
                name: item.name,
                isDetected: !item.isCatalog,
                size: size * 0.58,
              ),
            ),

            // Capa Metal FX: Reflejos especulares multicapa inspirados en metal-fx (Libraries.dev)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: const Alignment(-1.0, -1.0),
                      end: const Alignment(1.0, 1.0),
                      stops: const [0.0, 0.22, 0.48, 0.72, 1.0],
                      colors: [
                        Colors.white.withValues(alpha: 0.22),
                        Colors.transparent,
                        brandColor.withValues(alpha: 0.12),
                        Colors.white.withValues(alpha: 0.06),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // QUÉ HACE: Asigna el tono de acento según la procedencia del modelo.
  // POR QUÉ: Permite que el bisel y el resplandor 3D armonicen con cada empresa.
  static Color _resolveAccentColor(UnifiedModelItem item) {
    if (!item.isCatalog) return const Color(0xFF10B981);
    final n = item.name.toLowerCase();
    if (n.contains('deepseek')) return const Color(0xFF0284C7);
    if (n.contains('qwen')) return const Color(0xFF6366F1);
    if (n.contains('gemma')) return const Color(0xFF8B5CF6);
    if (n.contains('liquid') || n.contains('lfm')) return const Color(0xFFEC4899);
    if (n.contains('whisper')) return const Color(0xFF10B981);
    return const Color(0xFF14B8A6);
  }
}
