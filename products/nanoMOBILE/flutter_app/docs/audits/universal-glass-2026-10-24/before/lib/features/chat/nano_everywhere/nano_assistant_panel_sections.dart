import 'package:flutter/material.dart';
import 'nano_ai_controller.dart';
import 'nano_media_sheet.dart';

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
