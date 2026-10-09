// QUÉ HACE: Renderiza la tarjeta de recomendación de modelos LiteRT-LM en el carrusel.
// CÓMO FUNCIONA: Mapea datos reales de LmCatalogEntry y aplica diseño responsivo con Material Expressive.
// POR QUÉ: Corrige el error de desbordamiento (franja amarilla/RenderFlex overflow) mediante restricciones
// flexibles (Flexible + TextOverflow.ellipsis) y adapta la paleta tanto a modo oscuro como claro.
library;

import 'package:flutter/material.dart';
import 'models_carousel_data.dart';
export 'models_carousel_data.dart';
import '../../../../core/theme/design_tokens.dart';
import 'model_brand_logo.dart';

/// QUÉ HACE: Widget visual de la tarjeta del carrusel con prevención estricta de overflow.
/// CÓMO FUNCIONA: Organiza el encabezado, badges y evidencia en una columna con balance elástico.
class ModelsCarouselCard extends StatelessWidget {
  final RecommendedModelCardData model;
  final VoidCallback? onTap;

  const ModelsCarouselCard({super.key, required this.model, this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(NanoRadius.large),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            // La tarjeta no usa colores para atribuir calidad al modelo.
            color: colors.surface,
            borderRadius: BorderRadius.circular(NanoRadius.large),
            border: Border.all(color: colors.outlineVariant, width: 0.8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Fila 1: Logo, Título elástico (sin desborde), Badge de Nivel e Icono de Memoria
              Row(
                children: [
                  // El color pertenece al icono; textos y contorno siguen neutros.
                  ModelBrandLogo(name: model.title, size: 26),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            // CORRECCIÓN BUG OVERFLOW: Flexible previene que títulos largos rompan el ancho
                            Flexible(
                              child: Text(
                                model.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 13.0,
                                  fontWeight: FontWeight.w700,
                                  color: colors.onSurface,
                                ),
                              ),
                            ),
                            const SizedBox(width: 5),
                            // Badge compacto de nivel (Predeterminado o Avanzado)
                            _TierBadge(
                              isDefault: model.isDefault,
                              colors: colors,
                            ),
                          ],
                        ),
                        const SizedBox(height: 1),
                        Text(
                          '${model.params} • ${model.quantization} • ${model.downloadSize}',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 10.5,
                            color: colors.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.memory_rounded,
                    size: 16,
                    color: colors.onSurfaceVariant,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              // Descripción de arquitectura y memoria de referencia
              Text(
                '${model.description} • ${model.memoryReference}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 10.5,
                  color: colors.onSurface.withValues(alpha: 0.85),
                ),
              ),
              const Spacer(),
              // Fila inferior: Evidencia de hardware en el dispositivo
              Row(
                children: [
                  Icon(
                    Icons.phone_android_rounded,
                    size: 12.5,
                    color: colors.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      model.deviceEvidence,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 9.8,
                        fontWeight: FontWeight.w600,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// QUÉ HACE: Chip visual para indicar si el modelo es interactivo predeterminado o avanzado.
/// CÓMO FUNCIONA: Usa colores de diseño según el estado activo sin romper la horizontalidad.
class _TierBadge extends StatelessWidget {
  final bool isDefault;
  final NanoColors colors;

  const _TierBadge({required this.isDefault, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      decoration: BoxDecoration(
        color: colors.onSurfaceVariant.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: colors.outlineVariant, width: 0.8),
      ),
      child: Text(
        isDefault ? 'PRED. 1 PRUEBA' : 'AVANZADO',
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 8.5,
          fontWeight: FontWeight.w700,
          color: colors.onSurfaceVariant,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
