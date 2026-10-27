import 'package:flutter/material.dart';
import '../../engine/business/meta_templates_api.dart';
import '../../engine/business/meta_template_models.dart';

/// Lee plantillas aprobadas reales. Campos dinámicos numéricos de texto requieren
/// valores del usuario; no se rellenan con datos inventados del cliente.
Future<Map<String, dynamic>?> pickMetaSendTemplate(
  BuildContext context,
  MetaTemplatesApi api,
) async {
  try {
    final templates = (await api.listTemplates())
        .where((t) => t.status == 'APPROVED')
        .toList();
    if (!context.mounted) return null;
    final template = await showDialog<MetaMessageTemplate>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Plantillas aprobadas'),
        children: [
          if (templates.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text('No hay plantillas aprobadas disponibles.'),
            ),
          for (final t in templates)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, t),
              child: Text('${t.name} ? ${t.language}'),
            ),
        ],
      ),
    );
    if (template == null || !context.mounted) return null;
    final fields = <({String type, int count})>[];
    for (final component in template.components) {
      final type = '${component['type']}'.toLowerCase();
      if (!['header', 'body', 'buttons'].contains(type)) continue;
      final text = '${component['text'] ?? ''}';
      final matches = RegExp(r'\{\{(\d+)\}\}').allMatches(text);
      if (type == 'header' && component['format'] != 'TEXT' ||
          type == 'buttons' && '$component'.contains('{{') ||
          RegExp(r'\{\{[^0-9]').hasMatch(text)) {
        throw const FormatException(
          'Esta plantilla requiere parámetros especiales.',
        );
      }
      if (matches.isNotEmpty) {
        fields.add((
          type: type,
          count: matches
              .map((m) => int.parse(m[1]!))
              .reduce((a, b) => a > b ? a : b),
        ));
      }
    }
    if (fields.any((f) => f.count > 20)) {
      throw const FormatException('Demasiados parámetros.');
    }
    final controllers = [
      for (final f in fields)
        List.generate(f.count, (_) => TextEditingController()),
    ];
    try {
      if (controllers.isNotEmpty) {
        final accepted = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(template.name),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < fields.length; i++)
                    for (var j = 0; j < fields[i].count; j++)
                      TextField(
                        controller: controllers[i][j],
                        decoration: InputDecoration(
                          labelText: '${fields[i].type} ? valor ${j + 1}',
                        ),
                      ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () {
                  if (controllers
                      .expand((x) => x)
                      .every((c) => c.text.trim().isNotEmpty)) {
                    Navigator.pop(ctx, true);
                  }
                },
                child: const Text('Usar plantilla'),
              ),
            ],
          ),
        );
        if (accepted != true) return null;
      }
      return {
        'name': template.name,
        'language': {'code': template.language},
        if (fields.isNotEmpty)
          'components': [
            for (var i = 0; i < fields.length; i++)
              {
                'type': fields[i].type,
                'parameters': [
                  for (final c in controllers[i])
                    {'type': 'text', 'text': c.text.trim()},
                ],
              },
          ],
      };
    } finally {
      for (final c in controllers.expand((x) => x)) {
        c.dispose();
      }
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No se pudo preparar la plantilla. Revisa la conexión y los parámetros requeridos.',
          ),
        ),
      );
    }
    return null;
  }
}
