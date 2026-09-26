// model_item_card.dart — Tarjeta unificada de modelo neuronal (catálogo o SD).
// QUÉ HACE: Renderiza modelo con logo, specs de RAM/tamaño y acción directa.
// CÓMO FUNCIONA: Layout adaptativo (portrait/landscape), sin PopupMenuButton (0 crashes No Overlay).
// POR QUÉ: Asegura fluidez visual en Material Expressive 3 y cumple regla <200 líneas.
library;

import 'package:flutter/material.dart';
import '../../../../core/theme/adaptive_theme.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/nano_optical_surface.dart';
import 'model_action_components.dart';
import 'model_brand_logo.dart';
import 'model_screen_helpers.dart';

class ModelItemCard extends StatelessWidget {
  final UnifiedModelItem item;
  final bool isActive;
  final bool isLoading;
  final ModelUiStatus status;
  final VoidCallback onTapDetails;
  final VoidCallback? onUse;
  final VoidCallback? onDownload;
  final VoidCallback? onCancel;
  final VoidCallback? onUnload;
  final VoidCallback? onDelete;

  const ModelItemCard({
    super.key,
    required this.item,
    required this.isActive,
    required this.isLoading,
    required this.status,
    required this.onTapDetails,
    this.onUse,
    this.onDownload,
    this.onCancel,
    this.onUnload,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;
    final isLandscape = AdaptiveTheme.isLandscape(context);
    final isDownloading = status == ModelUiStatus.downloading;
    final cat = item.catalog;
    final progress = cat?.progress ?? 0.0;
    final error = cat?.error ?? (!item.installed && !item.isCatalog ? 'Incompatible' : null);

    return NanoOpticalSurface(
      borderRadius: NanoRadius.medium,
      margin: EdgeInsets.only(bottom: isLandscape ? 4 : 6),
      padding: EdgeInsets.symmetric(horizontal: isLandscape ? 8 : 10, vertical: isLandscape ? 6 : 8),
      onTap: onTapDetails,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ModelBrandLogo(name: item.name, isDetected: !item.isCatalog, size: isLandscape ? 32 : 36),
              SizedBox(width: isLandscape ? 7 : 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.name,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: isLandscape ? 12 : 13,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.2,
                              color: colors.onSurface,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        // Badge tipo de modelo (CHAT, RAZÓN, EDGE, NANO, etc.)
                        IosTag(label: item.typeTag, color: colors.primary),
                        // Badge recomendado para Nano Personal (dorado)
                        if (item.isRecommendedForNano) ...[
                          const SizedBox(width: 3),
                          const IosTag(label: '⭐ NANO', color: Color(0xFFF59E0B)),
                        ],
                        if (isActive) ...[
                          const SizedBox(width: 3),
                          const IosTag(label: 'ACTIVO', color: Color(0xFF10B981)),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: item.format,
                            style: TextStyle(fontFamily: 'Inter', fontSize: 10.5, fontWeight: FontWeight.w700, color: colors.primary),
                          ),
                          TextSpan(text: ' • ', style: TextStyle(color: colors.onSurfaceVariant.withValues(alpha: 0.5), fontSize: 10)),
                          TextSpan(
                            text: '${item.sizeGb.toStringAsFixed(1)} GB',
                            style: TextStyle(fontFamily: 'Inter', fontSize: 10.5, fontWeight: FontWeight.w600, color: colors.onSurface),
                          ),
                          if (item.ramGb > 0) ...[
                            TextSpan(text: ' • ', style: TextStyle(color: colors.onSurfaceVariant.withValues(alpha: 0.5), fontSize: 10)),
                            TextSpan(
                              text: 'RAM ~${item.ramGb.toStringAsFixed(1)} GB',
                              style: const TextStyle(fontFamily: 'Inter', fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFF10B981)),
                            ),
                          ],
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (!isLandscape || error != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        error ?? (cat != null ? cat.description : 'Archivo local en almacenamiento'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 10,
                          color: error != null ? colors.error : colors.onSurfaceVariant.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 6),
              _buildActionButton(colors),
            ],
          ),
          if (isDownloading) ...[
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: progress > 0 ? progress : null,
                backgroundColor: colors.primary.withValues(alpha: 0.15),
                valueColor: AlwaysStoppedAnimation(colors.primary),
                minHeight: 3,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Botón de acción directo inmune a ausencias de Overlay
  Widget _buildActionButton(NanoColors colors) {
    if (isLoading) {
      return const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (isActive) {
      return InkWell(
        onTap: onUnload,
        borderRadius: BorderRadius.circular(NanoRadius.small),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF10B981).withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(NanoRadius.small),
            border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.35)),
          ),
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.check_circle_rounded, size: 12, color: Color(0xFF10B981)),
            SizedBox(width: 3),
            Text('Activo', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF10B981))),
          ]),
        ),
      );
    }
    if (status == ModelUiStatus.installed) {
      final isVoice = item.catalog?.isVoiceStt ?? false;
      return IosActionButton(
        label: isVoice ? 'Activar' : 'Cargar',
        icon: isVoice ? Icons.mic_rounded : Icons.play_arrow_rounded,
        color: colors.primary,
        filled: true,
        onTap: onUse,
      );
    }
    if (status == ModelUiStatus.downloading) {
      return IosActionButton(label: 'Cancelar', icon: Icons.close_rounded, color: colors.error, onTap: onCancel);
    }
    return IosActionButton(label: 'Descargar', icon: Icons.download_rounded, color: colors.primary, onTap: onDownload);
  }
}
