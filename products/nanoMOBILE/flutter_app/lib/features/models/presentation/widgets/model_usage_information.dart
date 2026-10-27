// QUÉ: explicación verificable de la tarea, conexión y límites de cada modelo.
// CÓMO: consume la narrativa común y abre la fuente del archivo del catálogo.
// POR QUÉ: leer una ficha no debe confundir una descarga con una integración.
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'model_catalog_types.dart';

class ModelUsageInformation extends StatelessWidget {
  const ModelUsageInformation({super.key, required this.item});
  final UnifiedModelItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(item.modalityLabel, style: theme.textTheme.labelMedium),
        const SizedBox(height: 12),
        _paragraph(context, 'Para qué sirve', item.purposeNarrative),
        _paragraph(context, 'Disponible en Nano', item.nanoNarrative),
        _paragraph(context, 'Antes de elegirlo', item.limitNarrative),
        // Distingue el modelo original del publicador que preparó el archivo móvil.
        if (item.qwenOriginalSource case final String source)
          _sourceButton(context, source, 'Ficha oficial de Qwen'),
        if (item.catalog != null)
          _sourceButton(context, item.catalog!.url, 'Fuente del archivo'),
      ],
    );
  }

  /// Abre fuentes verificables sin convertir la página consultada en una descarga.
  Widget _sourceButton(BuildContext context, String url, String label) => Align(
    alignment: Alignment.centerLeft,
    child: TextButton.icon(
      onPressed: () async {
        final uri = Uri.tryParse(url);
        if (uri == null ||
            uri.scheme != 'https' ||
            uri.host != 'huggingface.co') {
          return;
        }
        final repo = uri.replace(
          pathSegments: uri.pathSegments.take(2).toList(),
          query: null,
          fragment: null,
        );
        try {
          final opened = await launchUrl(
            repo,
            mode: LaunchMode.externalApplication,
          );
          if (!opened && context.mounted) _showSourceError(context);
        } catch (_) {
          if (context.mounted) _showSourceError(context);
        }
      },
      icon: const Icon(Icons.open_in_new_rounded, size: 16),
      label: Text(label),
    ),
  );

  void _showSourceError(BuildContext context) =>
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir la fuente del modelo.')),
      );

  Widget _paragraph(BuildContext context, String title, String text) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(
              height: 1.5,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
