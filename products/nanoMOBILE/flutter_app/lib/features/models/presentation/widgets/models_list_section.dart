// models_list_section.dart — Lista categorizada de modelos neurales con tarjetas 3D.
// QUÉ HACE: Construye secciones agrupadas por categoría con tarjetas de perspectiva física 3D.
// CÓMO FUNCIONA: Mapea items a ModelPerspectiveCard ordenados verticalmente por categorías y familias.
// POR QUÉ: Permite navegación ergonómica y profesional de modelos en móvil (< 160 líneas).
library;

import 'package:flutter/material.dart';
import '../../../../core/services/whisper_stt_service.dart';
import '../../application/models_notifier.dart';
import 'model_action_components.dart';
import 'model_delete_confirmation.dart';
import 'model_perspective_card.dart';
import 'model_screen_helpers.dart';
import 'models_section_divider.dart';

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

    // Sin agrupación cuando el filtro no es "Todos".
    if (activeFilter != 'Todos') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ModelsSectionDivider(label: '$activeFilter · ${items.length}'),
          ...items.map((item) => _buildCard(context, item)),
        ],
      );
    }

    // Separar en instalados y disponibles; ambos usan las mismas categorías funcionales.
    final installed = items.where((i) => i.installed).toList();
    final available = items.where((i) => !i.installed).toList();
    final children = <Widget>[];

    // 1. — Sección instalados primero: listos para uso local inmediato.
    if (installed.isNotEmpty) {
      children.add(
        ModelsSectionDivider(
          label: 'Instalados en el dispositivo · ${installed.length}',
        ),
      );
      children.addAll(installed.map((item) => _buildCard(context, item)));
    }

    // Disponibles agrupados únicamente por lo que realmente hacen.
    if (available.isNotEmpty) {
      if (children.isNotEmpty) children.add(const SizedBox(height: 8));
      children.add(const ModelsSectionDivider(label: 'Catálogo por función'));
      final grouped = <String, List<UnifiedModelItem>>{};
      for (final it in available) {
        grouped.putIfAbsent(it.sectionTitle, () => []).add(it);
      }
      for (final entry in grouped.entries) {
        children.add(
          IosSectionHeader(title: entry.key, count: entry.value.length),
        );
        children.addAll(entry.value.map((item) => _buildCard(context, item)));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  // QUÉ HACE: Construye la tarjeta 3D con textos organizados sueltos y cuadro físico.
  // POR QUÉ: Estandariza la llamada de acciones y estados sin duplicación de código.
  Widget _buildCard(BuildContext context, UnifiedModelItem item) {
    final isVoice = item.catalog?.isVoiceStt ?? false;
    final isActive =
        item.runtimeReady &&
        (isVoice
            ? WhisperSttService.instance.activeModelFile == item.fileName
            : chatModel.toLowerCase() == item.name.toLowerCase());
    final status = item.installed && !item.runtimeReady
        ? ModelUiStatus.runtimeUnavailable
        : isActive
        ? ModelUiStatus.active
        : (item.isDownloading
              ? ModelUiStatus.downloading
              : (item.installed
                    ? ModelUiStatus.installed
                    : ModelUiStatus.available));

    return ModelPerspectiveCard(
      item: item,
      isActive: isActive,
      isLoading: item.catalog?.loading ?? false,
      status: status,
      onTapDetails: () => onShowDetails(item),
      onUse: !item.runtimeReady
          ? null
          : () => isActive
                ? (isVoice
                      ? notifier.unloadVoiceModel()
                      : notifier.unloadModel())
                : (item.isCatalog
                      ? notifier.loadModel(item.catalog!.id)
                      : notifier.useDetected(item.detected!)),
      onDownload: item.isCatalog
          ? () => notifier.downloadModel(item.catalog!.id)
          : null,
      onCancel: item.isCatalog ? () => notifier.cancelDownload() : null,
      onUnload: () =>
          isVoice ? notifier.unloadVoiceModel() : notifier.unloadModel(),
      onDelete: item.isCatalog
          ? () => confirmModelDeletion(
              context: context,
              modelName: item.name,
              fileName: item.fileName,
              delete: () => notifier.deleteModel(item.catalog!.id),
            )
          : null,
    );
  }
}
