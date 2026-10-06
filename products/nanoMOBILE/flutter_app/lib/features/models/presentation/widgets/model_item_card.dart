// QUÉ: tarjeta legible con información y acciones reales del modelo.
// CÓMO: tema Material, Wrap adaptable y acción existente; sin estrellas inventadas.
// POR QUÉ: no confundir decoración, capacidades originales o RAM con mediciones.
import 'package:flutter/material.dart';
import 'model_brand_logo.dart';
import 'model_card_action_button.dart';
import 'model_screen_helpers.dart';

class ModelItemCard extends StatelessWidget {
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
  final UnifiedModelItem item;
  final bool isActive, isLoading;
  final ModelUiStatus status;
  final VoidCallback onTapDetails;
  final VoidCallback? onUse, onDownload, onCancel, onUnload, onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final catalog = item.catalog;
    final downloading = status == ModelUiStatus.downloading;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: colors.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: colors.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTapDetails,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ModelBrandLogo(
                      name: item.name,
                      isDetected: !item.isCatalog,
                      size: 38,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            style: theme.textTheme.titleSmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              Text(
                                item.typeTag,
                                style: theme.textTheme.labelMedium,
                              ),
                              if (item.isRecommendedForNano)
                                Text(
                                  'Sugerido',
                                  style: theme.textTheme.labelMedium,
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Conserva cancelar, usar, descargar y descargar el motor.
                    ModelCardActionButton(
                      status: status,
                      isActive: isActive,
                      isLoading: isLoading,
                      sizeGb: item.sizeGb,
                      onUse: onUse,
                      onDownload: onDownload,
                      onCancel: onCancel,
                      onUnload: onUnload,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  catalog?.description ?? 'Archivo local en almacenamiento.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (downloading) ...[
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: (catalog?.progress ?? 0) > 0
                        ? catalog!.progress
                        : null,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
