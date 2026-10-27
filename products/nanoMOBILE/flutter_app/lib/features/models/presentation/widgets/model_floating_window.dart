// QUÉ: ficha real del catálogo con narrativa y progreso reactivo.
// CÓMO: observa el modelo por ID; separa cabecera, hechos y acciones.
// POR QUÉ: cancelar, cargar o descargar actualiza también la ventana abierta.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nanoai/core/widgets/glass_surface.dart';
import '../../../../core/providers/chat_provider.dart';
import '../../../../core/services/whisper_stt_service.dart';
import '../../../../core/services/runtime_engine.dart';
import '../../application/models_provider.dart';
import 'model_catalog_types.dart';
import 'model_download_progress.dart';
import 'model_3d_logo_box.dart';
import 'model_usage_information.dart';
import 'model_device_evidence_card.dart';
import 'model_window_facts.dart';
import 'model_window_actions.dart';

class ModelFloatingWindow extends ConsumerWidget {
  final UnifiedModelItem item;
  final bool isActive, isFavorite;
  final VoidCallback? onUse,
      onDownload,
      onCancel,
      onUnload,
      onDelete,
      onToggleFavorite,
      onCompare,
      onShare;

  const ModelFloatingWindow({
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(modelsProvider);
    final model = item.catalog == null
        ? null
        : state.models.where((m) => m.id == item.catalog!.id).firstOrNull;
    final shown = model == null ? item : UnifiedModelItem.catalog(model);
    final activeName = ref.watch(chatProvider.select((s) => s.activeModel));
    final engine = ref.watch(runtimeEngineProvider);
    final active =
        shown.runtimeReady &&
        (shown.catalog?.isVoiceStt == true
            ? WhisperSttService.instance.activeModelFile == shown.fileName
            : engine.phase == EnginePhase.ready && activeName == shown.name);
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 480,
            maxHeight: MediaQuery.sizeOf(context).height * .84,
          ),
          child: GlassSurface(
            radius: 22,
            blur: 24,
            opacity: .68,
            clarity: .88,
            intensity: .72,
            depth: 1.3,
            interactive: false,
            padding: EdgeInsets.zero,
            child: Material(
              type: MaterialType.transparency,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Model3DLogoBox(item: shown, size: 46),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                shown.company,
                                style: theme.textTheme.labelMedium,
                              ),
                              const SizedBox(height: 3),
                              Text(
                                shown.name,
                                style: theme.textTheme.titleMedium,
                              ),
                            ],
                          ),
                        ),
                        Semantics(
                          label: 'Cerrar ficha',
                          button: true,
                          child: IconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    ModelWindowFacts(item: shown),
                    const SizedBox(height: 16),
                    ModelUsageInformation(item: shown),
                    ModelDeviceEvidenceCard(modelName: shown.name),
                    const SizedBox(height: 12),
                    if (shown.isDownloading && model != null)
                      ModelDownloadProgress(model: model),
                    ModelWindowActions(
                      item: shown,
                      active: active,
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
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
