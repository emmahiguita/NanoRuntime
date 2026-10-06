// model_detail_sheet.dart — Ficha técnica y auditoría empírica de modelos para móvil.
// QUÉ HACE: Despliega información general, evidencia en teléfonos reales y botón "Probar modelo".
// CÓMO FUNCIONA: ModalBottomSheet deslizable con soporte de scroll vertical fluido e interactivo.
// POR QUÉ: Permite inspección técnica profunda sin desbordes y cumpliendo regla estricta < 200 líneas.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../application/models_provider.dart';
import '../../../terminal/presentation/widgets/perspective_hero_flight.dart';
import 'model_3d_logo_box.dart';
import 'model_catalog_types.dart';
import 'model_detail_general_info.dart';
import 'model_download_progress.dart';
import 'model_detail_quick_actions.dart';
import 'model_detail_use_cases.dart';
import 'model_device_evidence_card.dart';

class ModelDetailSheet extends ConsumerWidget {
  final UnifiedModelItem item;
  final bool isActive, isFavorite;
  final VoidCallback? onUse, onDownload, onCancel, onUnload, onDelete;
  final VoidCallback? onToggleFavorite, onCompare, onShare;

  const ModelDetailSheet({
    super.key,
    required this.item,
    required this.isActive,
    this.isFavorite = false,
    this.onUse,
    this.onDownload,
    this.onCancel,
    this.onUnload,
    this.onDelete,
    this.onToggleFavorite,
    this.onCompare,
    this.onShare,
  });

  static void show(
    BuildContext context, {
    required UnifiedModelItem item,
    required bool isActive,
    bool isFavorite = false,
    VoidCallback? onUse,
    VoidCallback? onDownload,
    VoidCallback? onCancel,
    VoidCallback? onUnload,
    VoidCallback? onDelete,
    VoidCallback? onToggleFavorite,
    VoidCallback? onCompare,
    VoidCallback? onShare,
  }) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(NanoRadius.large),
        ),
      ),
      builder: (_) => ModelDetailSheet(
        item: item,
        isActive: isActive,
        isFavorite: isFavorite,
        onUse: onUse,
        onDownload: onDownload,
        onCancel: onCancel,
        onUnload: onUnload,
        onDelete: onDelete,
        onToggleFavorite: onToggleFavorite,
        onCompare: onCompare,
        onShare: onShare,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Comparte el estado del catálogo para refrescar progreso y cancelación en esta ficha.
    final currentModel = item.catalog == null
        ? null
        : ref.watch(
            modelsProvider.select(
              (state) => state.models
                  .where((model) => model.id == item.catalog!.id)
                  .firstOrNull,
            ),
          );
    final shownItem = currentModel == null
        ? item
        : UnifiedModelItem.catalog(currentModel);
    final colors = NanoThemeExtension.of(context).colors;
    final cat = shownItem.catalog;
    final isVoice = cat?.isVoiceStt ?? false;
    final primaryAction = shownItem.isDownloading
        ? onCancel
        : shownItem.installed
        ? (isActive ? onUnload : onUse)
        : onDownload;

    return Material(
      color: colors.surface,
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(NanoRadius.large),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.outlineVariant.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Hero(
                    tag: 'model-box-${shownItem.name}',
                    flightShuttleBuilder: perspectiveHeroFlight,
                    child: Model3DLogoBox(item: shownItem, size: 54),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (item.isRecommendedForNano)
                          Container(
                            margin: const EdgeInsets.only(bottom: 2),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: colors.primaryContainer,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'RECOMENDADO',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 8.5,
                                fontWeight: FontWeight.w700,
                                color: colors.onPrimaryContainer,
                              ),
                            ),
                          ),
                        Text(
                          shownItem.name,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: colors.onSurface,
                          ),
                        ),
                        Text(
                          shownItem.company,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 11.5,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 5,
                children: [
                  _pillTag(item.typeTag, const Color(0xFF0284C7)),
                  if (cat?.isMultimodal ?? false)
                    _pillTag('MULTIMODAL', const Color(0xFF0D9488)),
                  _pillTag('INSTRUCCIONES', const Color(0xFF4F46E5)),
                  if (item.isRecommendedForNano)
                    _pillTag('NANO', colors.primary),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                cat?.description ??
                    (isVoice
                        ? 'Modelo local whisper.cpp para transcripción.'
                        : 'Inferencia local de red neuronal en GGUF.'),
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11.5,
                  height: 1.35,
                  color: colors.onSurface.withValues(alpha: 0.9),
                ),
              ),
              const SizedBox(height: 14),
              if (primaryAction != null)
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton.icon(
                    onPressed: primaryAction,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(NanoRadius.medium),
                      ),
                      elevation: 0,
                    ),
                    icon: Icon(
                      shownItem.isDownloading
                          ? Icons.close_rounded
                          : isActive
                          ? Icons.stop_rounded
                          : (shownItem.installed
                                ? Icons.play_arrow_rounded
                                : Icons.download_rounded),
                      size: 20,
                    ),
                    label: Text(
                      shownItem.isDownloading
                          ? 'Cancelar descarga'
                          : isActive
                          ? 'Descargar de memoria'
                          : (shownItem.installed
                                ? 'Probar modelo'
                                : 'Descargar para probar'),
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              // Mantiene visible el avance cuando la descarga se inicia desde esta ficha.
              if (shownItem.isDownloading && cat != null) ...[
                ModelDownloadProgress(model: cat),
                const SizedBox(height: 8),
              ],
              ModelDetailQuickActions(
                isInstalled: shownItem.installed,
                isDownloading: shownItem.isDownloading,
                isFavorite: isFavorite,
                onDownload: onDownload,
                onCancel: onCancel,
                onDelete: onDelete,
                onToggleFavorite: onToggleFavorite,
                onCompare: onCompare,
                onShare: onShare,
              ),
              const SizedBox(height: 12),
              ModelDetailGeneralInfo(item: item),
              const SizedBox(height: 14),
              ModelDeviceEvidenceCard(modelName: item.name),
              const SizedBox(height: 14),
              ModelDetailUseCases(
                isMultimodal: cat?.isMultimodal ?? false,
                isVoice: isVoice,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pillTag(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
