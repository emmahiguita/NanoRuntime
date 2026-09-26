// model_detail_sheet.dart — Modal estilo Material 3 / iOS para auditoría de modelos.
// QUÉ HACE: Despliega ficha técnica de cuantización, RAM, tamaño, motor y estado de activación.
// CÓMO FUNCIONA: ModalBottomSheet deslizable con soporte de scroll en horizontal y botones reactivos.
// POR QUÉ: Permite inspección técnica profunda sin desbordes y cumpliendo < 200 líneas.
library;

import 'package:flutter/material.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/nano_optical_surface.dart';
import 'model_action_components.dart';
import 'model_brand_logo.dart';
import 'model_catalog_types.dart';
import 'model_detail_actions.dart';
import 'model_spec_tile.dart';

class ModelDetailSheet extends StatelessWidget {
  final UnifiedModelItem item;
  final bool isActive;
  final VoidCallback? onUse, onDownload, onCancel, onUnload, onDelete;

  const ModelDetailSheet({
    super.key,
    required this.item,
    required this.isActive,
    this.onUse,
    this.onDownload,
    this.onCancel,
    this.onUnload,
    this.onDelete,
  });

  static void show(
    BuildContext context, {
    required UnifiedModelItem item,
    required bool isActive,
    VoidCallback? onUse,
    VoidCallback? onDownload,
    VoidCallback? onCancel,
    VoidCallback? onUnload,
    VoidCallback? onDelete,
  }) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(NanoRadius.large)),
      ),
      builder: (_) => ModelDetailSheet(
        item: item, isActive: isActive, onUse: onUse,
        onDownload: onDownload, onCancel: onCancel, onUnload: onUnload, onDelete: onDelete,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;
    final cat = item.catalog;
    final isVoice = cat?.isVoiceStt ?? false;

    return Material(
      color: colors.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(NanoRadius.large)),
      child: SafeArea(
        child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
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
                ModelBrandLogo(
                  name: item.name,
                  isDetected: !item.isCatalog,
                  size: 44,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          IosTag(
                            label: item.isCatalog
                                ? (isVoice
                                      ? 'Whisper MIT'
                                      : 'Catálogo Oficial')
                                : 'SD / Local',
                            color: const Color(0xFF10B981),
                          ),
                          const SizedBox(width: 6),
                          IosTag(
                            label: isVoice ? 'GGML STT' : item.format,
                            color: colors.primary,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(child: ModelSpecTile(label: 'Tamaño', value: '${item.sizeGb.toStringAsFixed(1)} GB', icon: Icons.storage_rounded)),
                const SizedBox(width: 8),
                Expanded(child: ModelSpecTile(label: 'RAM Mín.', value: cat != null ? '~${cat.ramGb.toStringAsFixed(1)} GB' : 'Auto', icon: Icons.memory_rounded)),
                const SizedBox(width: 8),
                Expanded(child: ModelSpecTile(label: 'Motor', value: isVoice ? 'Whisper.cpp' : (cat?.params ?? 'GGUF'), icon: Icons.layers_rounded)),
                const SizedBox(width: 8),
                Expanded(child: ModelSpecTile(label: 'Estado', value: item.installed ? 'Local' : 'Nube', icon: Icons.check_circle_outline_rounded)),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Descripción y uso',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 5),
            NanoOpticalSurface(
              borderRadius: NanoRadius.medium,
              padding: const EdgeInsets.all(10),
              child: Text(
                item.isCatalog && cat!.description.isNotEmpty
                    ? cat.description
                    : (isVoice
                          ? 'Modelo local whisper.cpp bajo licencia MIT.'
                          : 'Modelo neuronal en formato GGUF listo para ejecutarse en memoria.'),
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11.5,
                  height: 1.35,
                  color: colors.onSurface,
                ),
              ),
            ),
            const SizedBox(height: 14),
            ModelDetailActions(
              isActive: isActive,
              isInstalled: item.installed,
              isVoice: isVoice,
              isCatalog: item.isCatalog,
              onUse: onUse,
              onDownload: onDownload,
              onCancel: onCancel,
              onUnload: onUnload,
              onDelete: onDelete,
            ),
          ],
        ),
      ),
    ),
  );
}
}
