import 'dart:convert';

import 'package:flutter/material.dart';

import '../../engine/business/meta_template_models.dart';

/// Editor adaptativo; components conserva el esquema JSON oficial completo.
class MetaTemplateEditorDialog extends StatefulWidget {
  const MetaTemplateEditorDialog({super.key, this.initial});
  final MetaMessageTemplate? initial;

  @override
  State<MetaTemplateEditorDialog> createState() => _MetaTemplateEditorState();
}

class _MetaTemplateEditorState extends State<MetaTemplateEditorDialog> {
  late final TextEditingController _name;
  late final TextEditingController _language;
  late final TextEditingController _components;
  String? _category;
  String? _error;

  /// Precarga la plantilla remota o un cuerpo editable sin afirmar que existe.
  @override
  void initState() {
    super.initState();
    final item = widget.initial;
    _name = TextEditingController(text: item?.name ?? '');
    _language = TextEditingController(text: item?.language ?? '');
    _category = item?.category;
    _components = TextEditingController(
      text: const JsonEncoder.withIndent('  ').convert(item?.components ?? []),
    );
  }

  /// Libera los controladores al cerrar el editor.
  @override
  void dispose() {
    _name.dispose();
    _language.dispose();
    _components.dispose();
    super.dispose();
  }

  /// Valida la estructura local antes de enviar el JSON a Meta.
  void _save() {
    try {
      final decoded = jsonDecode(_components.text);
      if (decoded is! List ||
          decoded.isEmpty ||
          decoded.any((e) => e is! Map)) {
        throw const FormatException(
          'components debe ser una lista de objetos JSON.',
        );
      }
      final name = _name.text.trim();
      final locale = _language.text.trim();
      if (_category == null) {
        throw const FormatException('Selecciona la categoría de Meta.');
      }
      if (widget.initial == null &&
          !RegExp(r'^[a-z0-9_]{1,512}$').hasMatch(name)) {
        throw const FormatException(
          'Usa minúsculas, números y guion bajo en el nombre.',
        );
      }
      if (!RegExp(r'^[a-z]{2,3}(_[A-Z]{2})?$').hasMatch(locale)) {
        throw const FormatException(
          'Usa un idioma Meta válido, por ejemplo es_CO.',
        );
      }
      Navigator.pop(
        context,
        MetaMessageTemplateDraft(
          name: name,
          language: locale,
          category: _category!,
          components: [
            for (final item in decoded) (item as Map).cast<String, dynamic>(),
          ],
        ),
      );
    } on FormatException catch (error) {
      setState(() => _error = error.message);
    }
  }

  /// Ajusta el editor para pantallas pequeñas, grandes y orientación horizontal.
  @override
  Widget build(BuildContext context) {
    final landscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    return AlertDialog(
      scrollable: true,
      insetPadding: const EdgeInsets.all(16),
      title: Text(
        widget.initial == null
            ? 'Nueva plantilla Meta'
            : 'Editar plantilla Meta',
      ),
      content: SizedBox(
        width: landscape ? 680 : 520,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Los cambios se envían a Meta. La aprobación la decide Meta.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _name,
              readOnly: widget.initial != null,
              decoration: const InputDecoration(
                labelText: 'Nombre API',
                hintText: 'confirmacion_pedido',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _language,
              readOnly: widget.initial != null,
              decoration: const InputDecoration(
                labelText: 'Idioma',
                hintText: 'es_CO',
              ),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: const InputDecoration(labelText: 'Categoría Meta'),
              hint: const Text('Selecciona según el propósito del mensaje'),
              items: const [
                DropdownMenuItem(
                  value: 'UTILITY',
                  child: Text('Utility · transaccional'),
                ),
                DropdownMenuItem(
                  value: 'MARKETING',
                  child: Text('Marketing · promocional'),
                ),
                DropdownMenuItem(
                  value: 'AUTHENTICATION',
                  child: Text('Authentication · códigos'),
                ),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _category = value);
              },
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _components,
              minLines: 7,
              maxLines: 15,
              keyboardType: TextInputType.multiline,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              decoration: const InputDecoration(
                labelText: 'Components · JSON oficial',
                helperText:
                    'Permite encabezados, cuerpo, pie, medios y botones admitidos por Meta.',
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          onPressed: _save,
          icon: const Icon(Icons.cloud_upload_outlined),
          label: const Text('Enviar a Meta'),
        ),
      ],
    );
  }
}
