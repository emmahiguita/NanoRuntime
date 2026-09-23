// models_list_section.dart — Constructor de lista y secciones para modelos neurales.
// QUÉ HACE: Construye la lista categorizada por secciones (DeepSeek, Qwen, Whisper, etc) o estado vacío.
// CÓMO FUNCIONA: Mapea UnifiedModelItem a ModelItemCard con detección de modelo activo (LLM o Whisper).
// POR QUÉ: Evita duplicar lógica entre portrait y landscape, manteniendo ambos archivos < 200 líneas.
library;

import 'package:flutter/material.dart';
import '../../../../core/services/whisper_stt_service.dart';
import '../../application/models_notifier.dart';
import 'model_action_components.dart';
import 'model_item_card.dart';
import 'model_screen_helpers.dart';

class ModelsListSection extends StatelessWidget {
  final List<UnifiedModelItem> items;
  final String chatModel;
  final String activeFilter;
  final ModelsNotifier notifier;
  final ValueChanged<UnifiedModelItem> onShowDetails;

  const ModelsListSection({
    super.key,
    required this.items,
    required this.chatModel,
    required this.activeFilter,
    required this.notifier,
    required this.onShowDetails,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return IosEmptyState(
        title: 'Sin modelos disponibles',
        subtitle: 'No hay coincidencias para el filtro o término ingresado.',
        icon: Icons.psychology_outlined,
        actionLabel: 'Escanear Almacenamiento',
        onAction: () => notifier.scanStorageAll(),
      );
    }

    if (activeFilter != 'Todos') {
      return Column(
        children: items.map((item) => _buildCard(item)).toList(),
      );
    }

    final grouped = <String, List<UnifiedModelItem>>{};
    for (final it in items) {
      grouped.putIfAbsent(it.sectionTitle, () => []).add(it);
    }

    final children = <Widget>[];
    for (final entry in grouped.entries) {
      children.add(
        IosSectionHeader(title: entry.key, count: entry.value.length),
      );
      children.addAll(entry.value.map((item) => _buildCard(item)));
    }

    return Column(children: children);
  }

  Widget _buildCard(UnifiedModelItem item) {
    final isVoice = item.catalog?.isVoiceStt ?? false;
    final isActive = isVoice
        ? (WhisperSttService.instance.activeModelFile == item.fileName)
        : chatModel.toLowerCase().contains(item.name.toLowerCase());
    final isDownloading = item.isDownloading;
    final status = isActive
        ? ModelUiStatus.active
        : (isDownloading
              ? ModelUiStatus.downloading
              : (item.installed
                    ? ModelUiStatus.installed
                    : ModelUiStatus.available));

    return ModelItemCard(
      item: item,
      isActive: isActive,
      isLoading: false,
      status: status,
      onTapDetails: () => onShowDetails(item),
      onUse: () => item.isCatalog
          ? notifier.loadModel(item.catalog!.id)
          : notifier.useDetected(item.detected!),
      onDownload: item.isCatalog
          ? () => notifier.downloadModel(item.catalog!.id)
          : null,
      onCancel: item.isCatalog ? () => notifier.cancelDownload() : null,
      onUnload: isActive
          ? () =>
                (isVoice ? notifier.unloadVoiceModel() : notifier.unloadModel())
          : null,
      onDelete: item.isCatalog
          ? () => notifier.deleteModel(item.catalog!.id)
          : null,
    );
  }
}
