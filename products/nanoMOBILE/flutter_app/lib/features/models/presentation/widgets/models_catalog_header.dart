// models_catalog_header.dart — Encabezado editorial del catálogo de modelos.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/remote_inference_config.dart';
import '../../../../core/theme/design_tokens.dart';
import 'model_catalog_surface.dart';
import 'remote_inference_dialog.dart';

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
            child: Icon(
              remoteConfig.isRemote ? Icons.desktop_windows_rounded : Icons.psychology_rounded,
              color: remoteConfig.isRemote ? colors.accent : colors.onSurfaceVariant,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Modelos de IA',
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
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: colors.accent.withAlpha(30),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: colors.accent.withAlpha(90), width: 0.8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: Colors.greenAccent.shade400,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'PC GPU',
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
                      : 'Descarga, importa y administra modelos locales.',
                  maxLines: 1,
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
        ],
      ),
    );
  }
}
