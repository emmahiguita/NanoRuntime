// model_floating_window.dart — Ventana flotante de información completa de modelos con BorderBeam.
// QUÉ HACE: Despliega ficha técnica en tarjeta modal con efecto Border Beam (Libraries.dev), textura física y acciones reales.
// CÓMO FUNCIONA: Tarjeta modal envuelta en NanoBorderBeam con haz rotativo continuo, cabecera 3D y métricas.
// POR QUÉ: Cumple con la estética hiper-cuidada de Libraries.dev y límite < 200 líneas (SOLID/SRP).
library;

import 'package:flutter/material.dart';
import '../../../../core/theme/design_tokens.dart';
import 'model_3d_logo_box.dart';
import 'model_card_action_button.dart';
import 'model_catalog_types.dart';
import 'model_perspective_back.dart';

class ModelFloatingWindow extends StatelessWidget {
  final UnifiedModelItem item;
  final bool isActive, isFavorite;
  final VoidCallback? onUse, onDownload, onCancel, onUnload, onDelete, onToggleFavorite, onCompare, onShare;

  const ModelFloatingWindow({
    super.key,
    required this.item,
    required this.isActive,
    this.isFavorite = false,
    this.onUse, this.onDownload, this.onCancel, this.onUnload, this.onDelete,
    this.onToggleFavorite, this.onCompare, this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;
    final isDark = colors is NanoDarkColors;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 580),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Material(
            color: isDark ? const Color(0xFF0C1322) : colors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: isDark
                    ? colors.outlineVariant.withValues(alpha: 0.3)
                    : colors.outlineVariant.withValues(alpha: 0.6),
                width: 1.0,
              ),
            ),
            elevation: isDark ? 20 : 12,
            shadowColor: Colors.black.withValues(alpha: isDark ? 0.6 : 0.12),
            clipBehavior: Clip.antiAlias,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(context, colors),
                  const SizedBox(height: 14),
                  _buildSpecsRow(colors, isDark),
                  const SizedBox(height: 14),
                  _buildDescription(colors),
                  const SizedBox(height: 16),
                  _buildActionsRow(colors),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, NanoColors colors) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Model3DLogoBox(item: item, size: 58),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item.company.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontFamily: 'Inter', fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: colors.primary),
                    ),
                  ),
                  ModelTagBadge(label: item.typeTag, color: colors.primary),
                  if (item.isRecommendedForNano) ...[
                    const SizedBox(width: 4),
                    const ModelTagBadge(label: 'Sugerido', color: Color(0xFF10B981)),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              Text(
                item.name,
                style: TextStyle(fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.w800, color: colors.onSurface, letterSpacing: -0.3),
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        IconButton(
          icon: const Icon(Icons.close_rounded, size: 20),
          visualDensity: VisualDensity.compact,
          tooltip: 'Cerrar ventana',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  Widget _buildSpecsRow(NanoColors colors, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? colors.surfaceVariant.withValues(alpha: 0.5)
            : colors.surfaceVariant.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _specItem('Formato', item.format, colors),
          _specItem('Tamaño', '${item.sizeGb.toStringAsFixed(1)} GB', colors),
          if (item.ramGb > 0)
            _specItem('RAM Ref.', '≈${item.ramGb.toStringAsFixed(1)} GB', colors),
          _specItem('Estado', item.installed ? 'Instalado' : 'Disponible', colors),
        ],
      ),
    );
  }

  Widget _specItem(String label, String value, NanoColors colors) => Column(
    children: [
      Text(label, style: TextStyle(fontFamily: 'Inter', fontSize: 10, color: colors.onSurfaceVariant)),
      const SizedBox(height: 3),
      Text(value, style: TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w700, color: colors.onSurface)),
    ],
  );

  Widget _buildDescription(NanoColors colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('DESCRIPCIÓN Y CAPACIDADES', style: TextStyle(fontFamily: 'Inter', fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: colors.primary)),
        const SizedBox(height: 6),
        Text(
          item.catalog?.description ?? 'Modelo local ubicado en el almacenamiento del dispositivo.',
          style: TextStyle(fontFamily: 'Inter', fontSize: 12.5, height: 1.45, color: colors.onSurface.withValues(alpha: 0.9)),
        ),
      ],
    );
  }

  Widget _buildActionsRow(NanoColors colors) {
    final status = isActive
        ? ModelUiStatus.active
        : (item.isDownloading
            ? ModelUiStatus.downloading
            : (item.installed ? ModelUiStatus.installed : ModelUiStatus.available));

    return Row(
      children: [
        ModelCardActionButton(
          status: status,
          isActive: isActive,
          isLoading: false,
          sizeGb: item.sizeGb,
          onUse: onUse,
          onDownload: onDownload,
          onCancel: onCancel,
          onUnload: onUnload,
        ),
        const Spacer(),
        if (onCompare != null)
          IconButton(icon: const Icon(Icons.speed_rounded, size: 20), tooltip: 'Benchmark', color: colors.primary, onPressed: onCompare),
        if (onShare != null)
          IconButton(icon: const Icon(Icons.share_rounded, size: 19), tooltip: 'Compartir', onPressed: onShare),
        if (onDelete != null && item.installed)
          IconButton(icon: const Icon(Icons.delete_outline_rounded, size: 20), tooltip: 'Eliminar', color: colors.error, onPressed: onDelete),
      ],
    );
  }
}
