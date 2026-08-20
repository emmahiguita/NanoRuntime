/// Sábana Modal de Inspección Detallada de Modelos y Metadatos Verificados (SRP & M3E).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/live_animations.dart';
import '../../../../core/widgets/nano_components.dart';
import '../../data/model_source_registry.dart';
import '../../domain/model_metadata_entities.dart';
import '../../domain/model_viability.dart';
import 'model_brand_logos.dart';

class ModelDetailBottomSheet extends StatelessWidget {
  final String name;
  final String quant;
  final double sizeGb;
  final String description;
  final bool isDetected;
  final bool isActive;
  final VoidCallback onAction;
  final String actionLabel;
  final double phoneTotalRamGb;
  final VerifiedModelInfo verifiedInfo;
  final ModelSourceDefinition sourceDef;
  final double? ramGb;
  final String? path;

  const ModelDetailBottomSheet({
    super.key,
    required this.name,
    required this.quant,
    required this.sizeGb,
    required this.description,
    required this.isDetected,
    required this.isActive,
    required this.onAction,
    required this.actionLabel,
    required this.phoneTotalRamGb,
    required this.verifiedInfo,
    required this.sourceDef,
    this.ramGb,
    this.path,
  });

  static void show({
    required BuildContext context,
    required String name,
    required String quant,
    required double sizeGb,
    required String description,
    required bool isDetected,
    required bool isActive,
    required VoidCallback onAction,
    required String actionLabel,
    required double phoneTotalRamGb,
    required VerifiedModelInfo verifiedInfo,
    required ModelSourceDefinition sourceDef,
    double? ramGb,
    String? path,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (modalContext) {
        return ModelDetailBottomSheet(
          name: name,
          quant: quant,
          sizeGb: sizeGb,
          description: description,
          isDetected: isDetected,
          isActive: isActive,
          onAction: onAction,
          actionLabel: actionLabel,
          phoneTotalRamGb: phoneTotalRamGb,
          verifiedInfo: verifiedInfo,
          sourceDef: sourceDef,
          ramGb: ramGb,
          path: path,
        );
      },
    );
  }

  String _formatGb(double gb) => '${gb.toStringAsFixed(2)} GB';

  @override
  Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;
    final modelRam = verifiedInfo.estimatedRamGb.value ?? (isDetected ? 2.5 : 3.0);
    final deviceTotalRamGb = phoneTotalRamGb > 0 ? phoneTotalRamGb : 8.0;
    final ramRatio = (modelRam / deviceTotalRamGb).clamp(0.0, 1.0);
    // Verdicto alineado con el RuntimePlanner (Rust, umbrales 0.7/1.0/2.0).
    // Fallback síncrono offline; la autoridad real es /api/viability cuando
    // el motor está vivo.
    final viability = viabilityFor(modelRam, deviceTotalRamGb);

    final Color compatibilityColor;
    final String compatibilityLabel;
    final String compatibilityDescription;
    switch (viability) {
      case ModelViability.fast:
        compatibilityColor = colors.accentMint;
        compatibilityLabel = 'RÁPIDO';
        compatibilityDescription = '✓ Ejecución rápida y ligera en este dispositivo.';
        break;
      case ModelViability.balanced:
        compatibilityColor = colors.accentSky;
        compatibilityLabel = 'EQUILIBRADO';
        compatibilityDescription = '✓ Inferencia viable con residencia adaptativa.';
        break;
      case ModelViability.streaming:
        compatibilityColor = colors.warning;
        compatibilityLabel = 'STREAMING';
        compatibilityDescription = '⚠ Modelo mayor que la RAM: streaming de capas, lento.';
        break;
      case ModelViability.extreme:
        compatibilityColor = colors.error;
        compatibilityLabel = 'EXTREMO';
        compatibilityDescription = '⛔ Thrashing extremo: no interactivo.';
        break;
    }

    return GestureDetector(
      onDoubleTap: () => Navigator.of(context).pop(),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.90,
        ),
        margin: const EdgeInsets.fromLTRB(10, 0, 10, 16),
        child: NanoOpticalSurface(
          borderRadius: 24,
          blurSigma: 20,
          borderStrength: 0.90,
          reflectionStrength: 0.75,
          accent: colors.accentSky,
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header de arrastre + pista y botón cerrar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SizedBox(width: 28),
                  Column(
                    children: [
                      Container(
                        width: 38,
                        height: 4,
                        decoration: BoxDecoration(
                          color: colors.metalSilver.withValues(alpha: 0.80),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Desliza o doble toque para cerrar',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 9.5,
                          color: colors.textSecondary.withValues(alpha: 0.70),
                        ),
                      ),
                    ],
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colors.metalSilver.withValues(alpha: 0.25),
                      ),
                      child: Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: colors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header: Logo Oficial + Nombre + Desarrollador + Licencia
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FloatingModelIcon(
                            active: isActive,
                            child: ModelBrandLogo(name: name, size: 52),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        name,
                                        style: TextStyle(
                                          fontFamily: 'Inter',
                                          fontSize: 16.5,
                                          fontWeight: FontWeight.w800,
                                          color: colors.textPrimary,
                                          letterSpacing: -0.4,
                                        ),
                                      ),
                                    ),
                                    ProvenanceBadge(
                                      label: verifiedInfo.license.value ?? 'Licencia',
                                      provenance: verifiedInfo.license.provenance,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.verified_rounded,
                                      size: 13.5,
                                      color: colors.accentSky,
                                    ),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        verifiedInfo.developer.value ?? 'Desarrollador Oficial',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontFamily: 'Inter',
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w600,
                                          color: NanoTextColors.forText(
                                            colors.accentSky,
                                            colors,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    const ProvenanceBadge(
                                      label: 'OFICIAL',
                                      provenance: ModelDataProvenance.official,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Fuente GGUF: ${sourceDef.quantizationSource}',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 11,
                                    color: colors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // ==========================================
                      // SECCIÓN 1: ESPECIFICACIONES TÉCNICAS (OFICIALES)
                      // ==========================================
                      Text(
                        'Especificaciones del Modelo',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          VerifiedSpecBadge(
                            label: 'PARÁMETROS',
                            value: '${verifiedInfo.parametersBillions.value ?? "-"}B',
                            provenance: verifiedInfo.parametersBillions.provenance,
                            color: colors.accentMint,
                          ),
                          VerifiedSpecBadge(
                            label: 'VENTANA CONTEXTO',
                            value: '${verifiedInfo.contextLength.value ?? "-"} tokens',
                            provenance: verifiedInfo.contextLength.provenance,
                            color: colors.accentLavender,
                          ),
                          VerifiedSpecBadge(
                            label: 'VOCABULARIO',
                            value: '${verifiedInfo.vocabularySize.value ?? "-"} tokens',
                            provenance: verifiedInfo.vocabularySize.provenance,
                            color: colors.accentSky,
                          ),
                          VerifiedSpecBadge(
                            label: 'ARQUITECTURA BASE',
                            value: verifiedInfo.architecture.value ?? '-',
                            provenance: verifiedInfo.architecture.provenance,
                            color: colors.metalSilver,
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // ==========================================
                      // SECCIÓN 2: ARCHIVO INSTALABLE (GGUF)
                      // ==========================================
                      Text(
                        'Archivo GGUF & Cuantización',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          VerifiedSpecBadge(
                            label: 'CUANTIZACIÓN',
                            value: verifiedInfo.quantization.value ?? 'GGUF',
                            provenance: verifiedInfo.quantization.provenance,
                            color: colors.accentSky,
                          ),
                          VerifiedSpecBadge(
                            label: 'TAMAÑO EN DISCO',
                            value: sizeGb > 0 ? _formatGb(sizeGb) : 'Local',
                            provenance: ModelDataProvenance.quantization,
                            color: colors.accentMint,
                          ),
                          VerifiedSpecBadge(
                            label: 'ORIGEN DEL ARCHIVO',
                            value: sourceDef.quantizedRepo,
                            provenance: ModelDataProvenance.quantization,
                            color: colors.accentLavender,
                          ),
                        ],
                      ),

                      if (path != null) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: colors.backgroundSecondary.withValues(alpha: 0.60),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: colors.borderSecondaryColor),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.sd_storage_rounded, size: 16, color: colors.accentMint),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  path!,
                                  style: TextStyle(
                                    fontFamily: 'JetBrainsMono',
                                    fontSize: 10.5,
                                    color: colors.textSecondary,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 18),

                      // ==========================================
                      // SECCIÓN 3: ESTE DISPOSITIVO (NANOAI)
                      // ==========================================
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              'Compatibilidad con Este Dispositivo',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: colors.textPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: compatibilityColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: compatibilityColor.withValues(alpha: 0.35)),
                            ),
                            child: Text(
                              compatibilityLabel,
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                color: NanoTextColors.forText(
                                  compatibilityColor,
                                  colors,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colors.backgroundSecondary.withValues(alpha: 0.50),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: colors.borderSecondaryColor),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Wrap(
                                    spacing: 5,
                                    runSpacing: 2,
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    children: [
                                      Text(
                                        'RAM estimada: ~${modelRam.toStringAsFixed(1)} GB',
                                        style: TextStyle(
                                          fontFamily: 'Inter',
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: colors.textPrimary,
                                        ),
                                      ),
                                      const ProvenanceBadge(
                                        label: 'ESTIMADO',
                                        provenance: ModelDataProvenance.estimated,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Total: ${deviceTotalRamGb.toStringAsFixed(1)} GB (${(ramRatio * 100).toStringAsFixed(0)}%)',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: NanoTextColors.forText(
                                      ramRatio > 0.85
                                          ? colors.error
                                          : colors.accentSky,
                                      colors,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                height: 8,
                                color: colors.metalSilver.withValues(alpha: 0.35),
                                child: FractionallySizedBox(
                                  alignment: Alignment.centerLeft,
                                  widthFactor: ramRatio,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(6),
                                      gradient: LinearGradient(
                                        colors: ramRatio > 0.85
                                            ? [colors.warning, colors.error]
                                            : ramRatio > 0.65
                                                ? [colors.accentSky, colors.warning]
                                                : [colors.accentMint, colors.accentCyan],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              compatibilityDescription,
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 11,
                                color: colors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 18),

                      // ==========================================
                      // SECCIÓN 4: BENCHMARKS PUBLICADOS (REALES)
                      // ==========================================
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Benchmarks Publicados',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: colors.textPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const ProvenanceBadge(
                            label: 'OFICIAL / MODEL CARD',
                            provenance: ModelDataProvenance.official,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (verifiedInfo.benchmarks.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Text(
                            'No publicado por la fuente oficial.',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              color: colors.textSecondary,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        )
                      else
                        Column(
                          children: verifiedInfo.benchmarks.map((bench) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                                decoration: BoxDecoration(
                                  color: colors.backgroundSecondary.withValues(alpha: 0.45),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: colors.borderSecondaryColor),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            bench.name,
                                            style: TextStyle(
                                              fontFamily: 'Inter',
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: colors.textPrimary,
                                            ),
                                          ),
                                          if (bench.unit != null)
                                            Text(
                                              bench.unit!,
                                              style: TextStyle(
                                                fontFamily: 'Inter',
                                                fontSize: 10,
                                                color: colors.textSecondary,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      bench.value.toStringAsFixed(1),
                                      style: TextStyle(
                                        fontFamily: 'JetBrainsMono',
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                        color: NanoTextColors.forText(
                                          colors.accentSky,
                                          colors,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    ProvenanceBadge(
                                      label: 'OFICIAL',
                                      provenance: bench.source.provenance,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),

                      const SizedBox(height: 18),

                      // ==========================================
                      // SECCIÓN 5: CAPACIDADES DOCUMENTADAS
                      // ==========================================
                      Text(
                        'Capacidades Documentadas',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Column(
                        children: verifiedInfo.capabilities.map((cap) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: colors.accentSky.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: colors.accentSky.withValues(alpha: 0.20)),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(Icons.check_circle_outline_rounded, size: 15, color: colors.accentSky),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          cap.name,
                                          style: TextStyle(
                                            fontFamily: 'Inter',
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: colors.textPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          cap.description,
                                          style: TextStyle(
                                            fontFamily: 'Inter',
                                            fontSize: 11,
                                            color: colors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),

                      const SizedBox(height: 18),

                      // ==========================================
                      // SECCIÓN 6: FUENTES OFICIALES & TRAZABILIDAD
                      // ==========================================
                      Text(
                        'Fuentes y Trazabilidad',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Enlace 1: Model Card Oficial del Desarrollador
                      SourceLinkTile(
                        icon: Icons.developer_board_rounded,
                        title: 'Model Card Oficial del Desarrollador',
                        subtitle: sourceDef.officialRepo,
                        badgeLabel: 'OFICIAL',
                        url: 'https://huggingface.co/${sourceDef.officialRepo}',
                        badgeProvenance: ModelDataProvenance.official,
                      ),
                      const SizedBox(height: 6),

                      // Enlace 2: Repositorio de Cuantización GGUF
                      if (sourceDef.officialRepo != sourceDef.quantizedRepo)
                        SourceLinkTile(
                          icon: Icons.hub_rounded,
                          title: 'Repositorio GGUF / Cuantización',
                          subtitle: sourceDef.quantizedRepo,
                          badgeLabel: 'GGUF',
                          url: 'https://huggingface.co/${sourceDef.quantizedRepo}',
                          badgeProvenance: ModelDataProvenance.quantization,
                        ),

                      const SizedBox(height: 20),

                      // Botón de Acción Principal — content-sized (el CTA
                      // nunca se estira al ancho de la sábana/pantalla).
                      SizedBox(
                        height: 48,
                        child: NanoOpticalSurface(
                          borderRadius: 14,
                          blurSigma: 12,
                          borderStrength: 0.85,
                          reflectionStrength: 0.75,
                          accent: colors.accentSky,
                          onTap: () {
                            Navigator.of(context).pop();
                            onAction();
                          },
                          child: Center(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isActive ? Icons.check_circle_rounded : Icons.play_arrow_rounded,
                                  color: colors.textPrimary,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  actionLabel,
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: colors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ProvenanceBadge extends StatelessWidget {
  final String label;
  final ModelDataProvenance provenance;

  const ProvenanceBadge({
    super.key,
    required this.label,
    required this.provenance,
  });

  @override
  Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;

    final Color badgeColor;
    switch (provenance) {
      case ModelDataProvenance.official:
        badgeColor = colors.accentSky;
        break;
      case ModelDataProvenance.huggingFace:
        badgeColor = const Color(0xFFFF9D00);
        break;
      case ModelDataProvenance.quantization:
        badgeColor = colors.accentLavender;
        break;
      case ModelDataProvenance.localMeasured:
        badgeColor = colors.accentMint;
        break;
      case ModelDataProvenance.estimated:
        badgeColor = colors.metalSilver;
        break;
      case ModelDataProvenance.unavailable:
        badgeColor = colors.textSecondary;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: badgeColor.withValues(alpha: 0.35), width: 0.7),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'JetBrainsMono',
          fontSize: 8.5,
          fontWeight: FontWeight.w700,
          color: NanoTextColors.forText(badgeColor, colors),
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class VerifiedSpecBadge extends StatelessWidget {
  final String label;
  final String value;
  final ModelDataProvenance provenance;
  final Color color;

  const VerifiedSpecBadge({
    super.key,
    required this.label,
    required this.value,
    required this.provenance,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 8.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                  color: NanoTextColors.forText(color, colors),
                ),
              ),
              const SizedBox(width: 4),
              ProvenanceBadge(
                label: provenance == ModelDataProvenance.official
                    ? 'OFICIAL'
                    : provenance == ModelDataProvenance.quantization
                        ? 'GGUF'
                        : provenance == ModelDataProvenance.localMeasured
                            ? 'LOCAL'
                            : 'EST.',
                provenance: provenance,
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: colors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class SourceLinkTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String badgeLabel;
  final String url;
  final ModelDataProvenance badgeProvenance;

  const SourceLinkTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.badgeLabel,
    required this.url,
    required this.badgeProvenance,
  });

  @override
  Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;

    return NanoOpticalSurface(
      borderRadius: 12,
      blurSigma: 8,
      borderStrength: 0.60,
      reflectionStrength: 0.40,
      accent: colors.accentSky,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      child: Row(
        children: [
          Icon(icon, size: 18, color: colors.accentSky),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    ProvenanceBadge(
                      label: badgeLabel,
                      provenance: badgeProvenance,
                    ),
                  ],
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontFamily: 'JetBrainsMono',
                    fontSize: 10,
                    color: colors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy_rounded, size: 15),
            color: colors.accentSky,
            tooltip: 'Copiar enlace',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: url));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Enlace copiado: $url'),
                  duration: const Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.open_in_new_rounded, size: 15),
            color: colors.accentSky,
            tooltip: 'Abrir en navegador',
            onPressed: () async {
              final uri = Uri.parse(url);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
          ),
        ],
      ),
    );
  }
}
