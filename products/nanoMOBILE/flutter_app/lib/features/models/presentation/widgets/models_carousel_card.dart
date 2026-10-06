// QUÉ HACE: Renderiza la tarjeta de recomendación de modelos LiteRT-LM en el carrusel.
// CÓMO FUNCIONA: Mapea datos reales de LmCatalogEntry y aplica diseño responsivo con Material Expressive.
// POR QUÉ: Corrige el error de desbordamiento (franja amarilla/RenderFlex overflow) mediante restricciones
// flexibles (Flexible + TextOverflow.ellipsis) y adapta la paleta tanto a modo oscuro como claro.
library;

import 'package:flutter/material.dart';
import '../../../../core/models/catalog_models.dart';
import '../../../../core/theme/design_tokens.dart';
import 'model_brand_logo.dart';

/// QUÉ HACE: DTO (Data Transfer Object) inmutable con los metadatos de un modelo para la tarjeta.
/// CÓMO FUNCIONA: Extrae propiedades verificadas del catálogo sin benchmarks simulados.
class RecommendedModelCardData {
  final String title;
  final String params;
  final String quantization;
  final String downloadSize;
  final String memoryReference;
  final String description;
  final String deviceEvidence;
  final bool isDefault;

  const RecommendedModelCardData({
    required this.title,
    required this.params,
    required this.quantization,
    required this.downloadSize,
    required this.memoryReference,
    required this.description,
    required this.deviceEvidence,
    required this.isDefault,
  });

  /// CÓMO FUNCIONA: Fábrica que mapea LmCatalogEntry hacia la tarjeta visual.
  factory RecommendedModelCardData.fromCatalog(LmCatalogEntry entry) {
    final measuredOnOppo = entry.name == 'Qwen3-0.6B-Instruct (LiteRT)';
    final memoryNote = entry.name == 'Qwen2.5-1.5B-Instruct (LiteRT)'
        ? 'RAM ref. ≈${entry.ramGb.toStringAsFixed(1)} GB (otro)'
        : 'RAM ref. ≈${entry.ramGb.toStringAsFixed(1)} GB';
    return RecommendedModelCardData(
      title: entry.name,
      params: entry.params,
      quantization: entry.quant,
      downloadSize: '${entry.sizeGb.toStringAsFixed(2)} GB',
      memoryReference: memoryNote,
      description: 'Motor ${entry.backendType.name.toUpperCase()}',
      deviceEvidence: measuredOnOppo
          ? 'Prueba CPH2557: ≈7,53 tok/s; TTFT ≈12,2 s'
          : 'CPH2557: velocidad pendiente',
      isDefault: entry.tier == ModelTier.interactive,
    );
  }
}

/// QUÉ HACE: Widget visual de la tarjeta del carrusel con prevención estricta de overflow.
/// CÓMO FUNCIONA: Organiza el encabezado, badges y evidencia en una columna con balance elástico.
class ModelsCarouselCard extends StatelessWidget {
  final RecommendedModelCardData model;
  final VoidCallback? onTap;

  const ModelsCarouselCard({super.key, required this.model, this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;
    final isDark = colors is NanoDarkColors;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(NanoRadius.large),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [const Color(0xFF0F3826).withValues(alpha: 0.9), colors.surface.withValues(alpha: 0.95)]
                  : [const Color(0xFFFFFFFF), const Color(0xFFF0FDF4)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(NanoRadius.large),
            border: Border.all(
              color: colors.primary.withValues(alpha: isDark ? 0.40 : 0.25),
              width: 1.2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Fila 1: Logo, Título elástico (sin desborde), Badge de Nivel e Icono de Memoria
              Row(
                children: [
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
                            _TierBadge(isDefault: model.isDefault, colors: colors),
                          ],
                        ),
                        const SizedBox(height: 1),
                        Text(
                          '${model.params} • ${model.quantization} • ${model.downloadSize}',
                          style: TextStyle(fontFamily: 'Inter', fontSize: 10.5, color: colors.onSurfaceVariant),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.memory_rounded, size: 16, color: colors.primary),
                ],
              ),
              const SizedBox(height: 6),
              // Descripción de arquitectura y memoria de referencia
              Text(
                '${model.description} • ${model.memoryReference}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontFamily: 'Inter', fontSize: 10.5, color: colors.onSurface.withValues(alpha: 0.85)),
              ),
              const Spacer(),
              // Fila inferior: Evidencia de hardware en el dispositivo
              Row(
                children: [
                  Icon(Icons.phone_android_rounded, size: 12.5, color: colors.primary),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      model.deviceEvidence,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontFamily: 'Inter', fontSize: 9.8, fontWeight: FontWeight.w600, color: colors.primary),
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
        color: colors.primary.withValues(alpha: 0.20),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: colors.primary.withValues(alpha: 0.35), width: 0.8),
      ),
      child: Text(
        isDefault ? 'PRED. 1 PRUEBA' : 'AVANZADO',
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 8.5,
          fontWeight: FontWeight.w700,
          color: colors.primary,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}