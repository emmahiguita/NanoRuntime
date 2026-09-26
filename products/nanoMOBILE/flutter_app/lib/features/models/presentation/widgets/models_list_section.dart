// models_list_section.dart — Lista categorizada de modelos neurales con separadores.
// QUÉ HACE: Construye secciones agrupadas por familia, badge de recomendado, separador instalados/disponibles.
// CÓMO FUNCIONA: Primero instalados (con separador verde), luego disponibles agrupados por sección.
// POR QUÉ: El usuario ve inmediatamente lo que puede usar; las familias mantienen orden visual limpio.
library;

import 'package:flutter/material.dart';
import '../../../../core/services/whisper_stt_service.dart';
import '../../../../core/theme/design_tokens.dart';
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

    // Sin agrupación cuando el filtro no es "Todos".
    if (activeFilter != 'Todos') {
      return Column(
        children: items.map(_buildCard).toList(),
      );
    }

    // Separar en instalados y disponibles (ya vienen ordenados de ModelFilterHelper).
    final installed = items.where((i) => i.installed).toList();
    final available = items.where((i) => !i.installed).toList();
    final children = <Widget>[];

    // 1. — Sección instalados primero: listos para uso local inmediato.
    if (installed.isNotEmpty) {
      children.add(_SectionDivider(
        label: 'INSTALADOS EN EL DISPOSITIVO • ${installed.length}',
        color: const Color(0xFF10B981),
      ));
      children.addAll(installed.map(_buildCard));
    }

    // 2. — Sección recomendados para móvil (<1GB RAM, rápidos, cero calentamiento).
    final recommended = available.where((i) => i.isRecommendedForNano).toList();
    if (recommended.isNotEmpty) {
      if (children.isNotEmpty) children.add(const SizedBox(height: 6));
      children.add(const _SectionDivider(
        label: '⭐ RECOMENDADOS PARA MOBILE (<1GB RAM, SIN CALOR)',
        color: Color(0xFFF59E0B),
      ));
      children.addAll(recommended.map(_buildCard));
    }

    // 3. — Herramientas especializadas (Whisper Voz, Visión o Coder).
    final specialized = available
        .where((i) => !i.isRecommendedForNano && i.isSpecialized)
        .toList();
    if (specialized.isNotEmpty) {
      if (children.isNotEmpty) children.add(const SizedBox(height: 6));
      children.add(const _SectionDivider(
        label: '🎙️ HERRAMIENTAS & FUNCIONES (VOZ / VISIÓN / CÓDIGO)',
        color: Color(0xFF8B5CF6),
      ));
      children.addAll(specialized.map(_buildCard));
    }

    // 4. — Sección general disponible agrupada por familia.
    final general = available
        .where((i) => !i.isRecommendedForNano && !i.isSpecialized)
        .toList();
    if (general.isNotEmpty) {
      if (children.isNotEmpty) children.add(const SizedBox(height: 6));
      children.add(const _SectionDivider(
        label: 'CATÁLOGO GENERAL DE MODELOS (GGUF)',
        color: null,
      ));
      final grouped = <String, List<UnifiedModelItem>>{};
      for (final it in general) {
        grouped.putIfAbsent(it.sectionTitle, () => []).add(it);
      }
      for (final entry in grouped.entries) {
        children.add(IosSectionHeader(title: entry.key, count: entry.value.length));
        children.addAll(entry.value.map(_buildCard));
      }
    }

    return Column(children: children);
  }

  // QUÉ HACE: Construye ModelItemCard con status correcto y badge de recomendado.
  // POR QUÉ: Centraliza la lógica de estado para no duplicarla en portrait/landscape.
  Widget _buildCard(UnifiedModelItem item) {
    final isVoice = item.catalog?.isVoiceStt ?? false;
    final isActive = isVoice
        ? (WhisperSttService.instance.activeModelFile == item.fileName)
        : chatModel.toLowerCase().contains(item.name.toLowerCase());
    final status = isActive
        ? ModelUiStatus.active
        : (item.isDownloading
            ? ModelUiStatus.downloading
            : (item.installed ? ModelUiStatus.installed : ModelUiStatus.available));

    return ModelItemCard(
      item: item,
      isActive: isActive,
      isLoading: false,
      status: status,
      onTapDetails: () => onShowDetails(item),
      onUse: () => item.isCatalog
          ? notifier.loadModel(item.catalog!.id)
          : notifier.useDetected(item.detected!),
      onDownload: item.isCatalog ? () => notifier.downloadModel(item.catalog!.id) : null,
      onCancel: item.isCatalog ? () => notifier.cancelDownload() : null,
      onUnload: isActive
          ? () => (isVoice ? notifier.unloadVoiceModel() : notifier.unloadModel())
          : null,
      onDelete: item.isCatalog ? () => notifier.deleteModel(item.catalog!.id) : null,
    );
  }
}

/// Separador de sección con etiqueta coloreada (instalados / disponibles).
// QUÉ HACE: Divide visualmente la lista entre modelos instalados y disponibles.
// POR QUÉ: Sin separador, el usuario no distingue qué puede usar ahora.
class _SectionDivider extends StatelessWidget {
  final String label;
  final Color? color; // null = usa color de superficie

  const _SectionDivider({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;
    final effectiveColor = color ?? colors.onSurfaceVariant.withValues(alpha: 0.5);
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 6),
      child: Row(children: [
        Container(width: 3, height: 12, decoration: BoxDecoration(
          color: effectiveColor, borderRadius: BorderRadius.circular(2),
        )),
        const SizedBox(width: 7),
        Text(label, style: TextStyle(
          fontFamily: 'Inter', fontSize: 10,
          fontWeight: FontWeight.w700, letterSpacing: 0.6,
          color: effectiveColor,
        )),
        const SizedBox(width: 8),
        Expanded(child: Container(height: 0.5, color: effectiveColor.withValues(alpha: 0.25))),
      ]),
    );
  }
}
