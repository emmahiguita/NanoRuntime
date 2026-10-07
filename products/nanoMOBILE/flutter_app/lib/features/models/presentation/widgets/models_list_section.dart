// models_list_section.dart — Lista categorizada de modelos neurales con tarjetas 3D.
// QUÉ HACE: Construye secciones agrupadas por categoría con tarjetas de perspectiva física 3D.
// CÓMO FUNCIONA: Mapea items a ModelPerspectiveCard ordenados verticalmente por categorías y familias.
// POR QUÉ: Permite navegación ergonómica y profesional de modelos en móvil (< 160 líneas).
library;

import 'package:flutter/material.dart';
import '../../../../core/services/whisper_stt_service.dart';
import '../../../../core/theme/design_tokens.dart';
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
          ModelsSectionDivider(
            label: '$activeFilter • ${items.length}'.toUpperCase(),
            color: NanoThemeExtension.of(context).colors.primary,
          ),
          ...items.map((item) => _buildCard(context, item)),
        ],
      );
    }

    // Separar en instalados y disponibles con orden estable.
    final installed = items.where((i) => i.installed).toList();
    final available = items.where((i) => !i.installed).toList();
    final children = <Widget>[];

    // 1. — Sección instalados primero: listos para uso local inmediato.
    if (installed.isNotEmpty) {
      children.add(
        ModelsSectionDivider(
          label: 'INSTALADOS EN EL DISPOSITIVO • ${installed.length}',
          color: const Color(0xFF10B981),
        ),
      );
      children.addAll(installed.map((item) => _buildCard(context, item)));
    }

    // 2. — Recomendaciones declaradas por la política central del catálogo.
    final recommended = available.where((i) => i.isRecommendedForNano).toList();
    if (recommended.isNotEmpty) {
      if (children.isNotEmpty) children.add(const SizedBox(height: 8));
      children.add(
        ModelsSectionDivider(
          label: 'RECOMENDADOS PARA MÓVIL',
          color: NanoThemeExtension.of(context).colors.primary,
        ),
      );
      children.addAll(recommended.map((item) => _buildCard(context, item)));
    }

    // 3. — Herramientas especializadas (Whisper Voz, Visión o Coder).
    final specialized = available
        .where((i) => !i.isRecommendedForNano && i.isSpecialized)
        .toList();
    if (specialized.isNotEmpty) {
      if (children.isNotEmpty) children.add(const SizedBox(height: 8));
      children.add(
        ModelsSectionDivider(
          label: '🎙️ HERRAMIENTAS & FUNCIONES (VOZ / VISIÓN / CÓDIGO)',
          color: NanoThemeExtension.of(context).colors.primary,
        ),
      );
      children.addAll(specialized.map((item) => _buildCard(context, item)));
    }

    // 4. — Sección general disponible agrupada por familia.
    final general = available
        .where((i) => !i.isRecommendedForNano && !i.isSpecialized)
        .toList();
    if (general.isNotEmpty) {
      if (children.isNotEmpty) children.add(const SizedBox(height: 8));
      children.add(
        const ModelsSectionDivider(
          label: 'CATÁLOGO GENERAL DE MODELOS',
          color: null,
        ),
      );
      final grouped = <String, List<UnifiedModelItem>>{};
      for (final it in general) {
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
    final isActive = isVoice
        ? (WhisperSttService.instance.activeModelFile == item.fileName)
        : (chatModel.isNotEmpty &&
            (chatModel.toLowerCase() == item.name.toLowerCase() ||
             item.name.toLowerCase().contains(chatModel.toLowerCase()) ||
             chatModel.toLowerCase().contains(item.name.toLowerCase())));
    final status = isActive
        ? ModelUiStatus.active
        : (item.isDownloading
              ? ModelUiStatus.downloading
              : (item.installed
                    ? ModelUiStatus.installed
                    : ModelUiStatus.available));

    return ModelPerspectiveCard(
      item: item,
      isActive: isActive,
      isLoading: false,
      status: status,
      onTapDetails: () => onShowDetails(item),
      onUse: () => isActive
          ? (isVoice ? notifier.unloadVoiceModel() : notifier.unloadModel())
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
