// models_catalog_header.dart — Encabezado editorial del catálogo de modelos.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/remote_inference_config.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/feather_core_icon.dart';
import '../../application/models_provider.dart';
import 'model_catalog_surface.dart';
import 'remote_inference_dialog.dart';
import 'hugging_face_model_import_dialog.dart';

class ModelsCatalogHeader extends ConsumerWidget {
  const ModelsCatalogHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = NanoThemeExtension.of(context).colors;
    final remoteConfig = ref.watch(remoteInferenceConfigProvider);

    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: modelCatalogSurface(context),
              borderRadius: BorderRadius.circular(NanoRadius.medium),
              border: Border.all(color: colors.outlineVariant, width: 0.8),
            ),
            child: FeatherCoreIcon(
              type: remoteConfig.isRemote
                  ? FeatherCoreType.network
                  : FeatherCoreType.models,
              framed: false,
              accentColor: colors.onSurfaceVariant,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    Text(
                      'Elige según tu tarea',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        color: colors.onSurface,
                      ),
                    ),
                    if (remoteConfig.isRemote) ...[
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => showRemoteInferenceSheet(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: colors.accent.withAlpha(30),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: colors.accent.withAlpha(90),
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: colors.onSurfaceVariant,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Destino PC',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: colors.accent,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  remoteConfig.isRemote
                      ? 'Inferencia delegada a PC: ${remoteConfig.serverUrl}'
                      : 'Compara funciones y disponibilidad antes de descargar.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Importar GGUF desde Hugging Face',
            onPressed: () async {
              final imported = await showHuggingFaceModelImportDialog(
                context: context,
                notifier: ref.read(modelsProvider.notifier),
              );
              if (!context.mounted || imported == null) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    '${imported.name} quedó importado en modelos locales.',
                  ),
                ),
              );
            },
            icon: const Icon(Icons.add_link_rounded),
          ),
        ],
      ),
    );
  }
}
