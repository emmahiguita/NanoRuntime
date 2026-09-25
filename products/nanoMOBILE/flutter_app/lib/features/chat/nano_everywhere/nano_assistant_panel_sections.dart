import 'package:flutter/material.dart';
import 'nano_ai_controller.dart';
import 'nano_ai_models.dart';
import 'nano_media_sheet.dart';

/// Selección múltiple explícita; el panel mantiene al menos un proveedor.
class NanoProviderSelector extends StatelessWidget {
  const NanoProviderSelector({
    super.key,
    required this.providers,
    required this.selectedIds,
    required this.onChanged,
    this.enabled = true,
  });
  final List<NanoProvider> providers;
  final Set<String> selectedIds;
  final void Function(String id, bool selected) onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: providers
          .map(
            (provider) => Padding(
              padding: const EdgeInsets.only(right: 6),
              child: FilterChip(
                label: Text(provider.name),
                selected: selectedIds.contains(provider.id),
                onSelected: enabled ? (value) => onChanged(provider.id, value) : null,
              ),
            ),
          )
          .toList(),
    ),
  );
}

/// Un único botón inicia o descarta la consulta; no duplica el spinner del búho.
class NanoAssistantPrimaryAction extends StatelessWidget {
  const NanoAssistantPrimaryAction({
    super.key,
    required this.busy,
    required this.isMedia,
    required this.onPressed,
    required this.onCancel,
  });
  final bool busy, isMedia;
  final VoidCallback onPressed, onCancel;

  @override
  Widget build(BuildContext context) => FilledButton.icon(
    onPressed: busy ? onCancel : onPressed,
    icon: Icon(busy ? Icons.close_rounded : Icons.arrow_upward_rounded),
    label: Text(
      busy
          ? 'Descartar consulta'
          : isMedia
          ? 'Detectar archivos'
          : 'Enviar',
    ),
  );
}

/// Muestra directamente la lista de descarga (MP4/MP3) cuando hay elementos detectados.
class NanoMediaManagerLink extends StatelessWidget {
  const NanoMediaManagerLink({super.key, required this.controller});
  final NanoAiController controller;

  @override
  Widget build(BuildContext context) {
    if (controller.detectedMedia.isNotEmpty) {
      return NanoMediaSheet(controller: controller);
    }
    return TextButton.icon(
      onPressed: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => NanoMediaSheet(controller: controller),
      ),
      icon: const Icon(Icons.folder_open_rounded),
      label: const Text('Abrir archivos detectados'),
    );
  }
}

/// Sugerencias del resultado actual, inactivas mientras existe otra consulta.
class NanoAssistantSuggestionChips extends StatelessWidget {
  const NanoAssistantSuggestionChips({
    super.key,
    required this.suggestions,
    required this.onSelected,
    this.enabled = true,
  });
  final List<String> suggestions;
  final ValueChanged<String> onSelected;
  final bool enabled;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 6,
    runSpacing: 4,
    children: suggestions
        .map(
          (suggestion) => ActionChip(
            label: Text(suggestion),
            onPressed: enabled ? () => onSelected(suggestion) : null,
          ),
        )
        .toList(),
  );
}
