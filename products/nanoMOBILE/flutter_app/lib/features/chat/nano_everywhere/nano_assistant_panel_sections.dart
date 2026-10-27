// nano_assistant_panel_sections.dart — Secciones y acciones en cristal líquido iOS transparente.
// QUÉ HACE: Tarjetas de descarga directa y chips de sugerencias en cristal líquido Apple.
// CÓMO FUNCIONA: Micro-superficies transparentes que conservan la visión del contenido posterior.
// POR QUÉ: Diseño 100% homogéneo y sin elementos que obstruyan el fondo de pantalla.
library;

import 'package:flutter/material.dart';
import 'nano_ai_controller.dart';
import 'nano_ai_models.dart';
import 'nano_media_sheet.dart';
import 'package:nanoai/core/widgets/nano_glass_window.dart';

/// Fila de descarga rápida en cristal líquido transparente.
class NanoMediaDownloadRow extends StatelessWidget {
  const NanoMediaDownloadRow({
    super.key,
    required this.resource,
    required this.onDownload,
  });

  final NanoMediaResource resource;
  final void Function(String url, bool audioOnly) onDownload;

  @override
  Widget build(BuildContext context) {
    final domain = Uri.tryParse(resource.url)?.host ?? 'Multimedia';

    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(resource.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '${resource.typeLabel} · $domain',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: IconButton(
        tooltip: 'Descargar archivo original',
        onPressed: () => onDownload(resource.url, false),
        icon: const Icon(Icons.download_rounded),
      ),
    );
  }
}

/// Enlace discreto para abrir archivos detectados.
class NanoMediaManagerLink extends StatelessWidget {
  const NanoMediaManagerLink({super.key, required this.controller});
  final NanoAiController controller;

  @override
  Widget build(BuildContext context) {
    if (controller.detectedMedia.isNotEmpty) {
      return NanoMediaSheet(controller: controller);
    }
    return TextButton(
      onPressed: () => showNanoGlassWindow(
        context: context,
        builder: (_) => NanoMediaSheet(controller: controller),
      ),
      child: const Text(
        'Ver archivos detectados',
        style: TextStyle(color: Colors.white70, fontSize: 11.5),
      ),
    );
  }
}

/// Sugerencias sobrias en píldoras de cristal translúcido.
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
            label: Text(suggestion, style: const TextStyle(fontSize: 11)),
            backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
            side: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            onPressed: enabled ? () => onSelected(suggestion) : null,
          ),
        )
        .toList(),
  );
}

/// Botón discreto para cancelar consultas en curso.
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
  Widget build(BuildContext context) {
    if (!busy) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Center(
        child: TextButton.icon(
          onPressed: onCancel,
          icon: const Icon(Icons.stop_circle_outlined, size: 18),
          label: const Text('Detener'),
        ),
      ),
    );
  }
}
