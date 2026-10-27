import 'dart:convert';
import 'package:flutter/material.dart';
import '../../engine/business/meta_template_content.dart';
import '../../engine/business/meta_template_models.dart';
import 'meta_template_editor_fields.dart';

/// Editor real de plantillas: texto legible con JSON oficial opcional.
/// El diálogo devuelve un borrador; la pantalla lo persiste mediante el gateway.
class MetaTemplateEditorDialog extends StatefulWidget {
  const MetaTemplateEditorDialog({super.key, this.initial});
  final MetaMessageTemplate? initial;

  @override
  State<MetaTemplateEditorDialog> createState() => _MetaTemplateEditorState();
}

class _MetaTemplateEditorState extends State<MetaTemplateEditorDialog> {
  late final TextEditingController _name, _language, _components, _body;
  String? _category, _error;
  bool _advanced = false;
  static const _categories = ['UTILITY', 'MARKETING', 'AUTHENTICATION'];

  @override
  void initState() {
    super.initState();
    final item = widget.initial;
    _name = TextEditingController(text: item?.name ?? '');
    _language = TextEditingController(text: item?.language ?? '');
    _category = _categories.contains(item?.category) ? item!.category : null;
    _components = TextEditingController(
      text: const JsonEncoder.withIndent('  ').convert(item?.components ?? []),
    );
    _body = TextEditingController(
      text: MetaTemplateContent.body(item?.components ?? []),
    );
    // Las plantillas OTP tienen componentes especializados, no texto libre.
    _advanced = _category == 'AUTHENTICATION';
  }

  @override
  void dispose() {
    for (final controller in [_name, _language, _components, _body]) {
      controller.dispose();
    }
    super.dispose();
  }

  /// Lee JSON sin modificarlo: tipos inválidos generan un error visible.
  List<Map<String, dynamic>> _readComponents() {
    final decoded = jsonDecode(_components.text);
    if (decoded is! List || decoded.any((e) => e is! Map<String, dynamic>)) {
      throw const FormatException('Los componentes deben ser una lista JSON.');
    }
    return decoded.cast<Map<String, dynamic>>();
  }

  /// Sincroniza al cambiar de modo para no perder ediciones ni botones remotos.
  void _toggleAdvanced(bool value) {
    try {
      if (value) {
        _components.text = const JsonEncoder.withIndent(
          '  ',
        ).convert(MetaTemplateContent.withBody(_readComponents(), _body.text));
      } else {
        _body.text = MetaTemplateContent.body(_readComponents());
      }
      setState(() {
        _advanced = value;
        _error = null;
      });
    } on FormatException catch (error) {
      setState(() => _error = error.message);
    }
  }

  /// Valida solo lo comprobable localmente; el servidor decide la aprobación.
  void _save() {
    try {
      final name = _name.text.trim(), locale = _language.text.trim();
      if (_category == null) {
        throw const FormatException('Selecciona la categoría de Meta.');
      }
      if (widget.initial == null &&
          !RegExp(r'^[a-z0-9_]{1,512}$').hasMatch(name)) {
        throw const FormatException(
          'Nombre: minúsculas, números y guion bajo.',
        );
      }
      if (!RegExp(r'^[a-z]{2,3}(_[A-Z]{2})?$').hasMatch(locale)) {
        throw const FormatException('Indica el idioma, por ejemplo es_CO.');
      }
      if (!_advanced && _body.text.trim().isEmpty) {
        throw const FormatException('Escribe el cuerpo del mensaje.');
      }
      final components = _advanced
          ? _readComponents()
          : MetaTemplateContent.withBody(_readComponents(), _body.text.trim());
      if (components.isEmpty) {
        throw const FormatException('Añade los componentes de la plantilla.');
      }
      Navigator.pop(
        context,
        MetaMessageTemplateDraft(
          name: name,
          language: locale,
          category: _category!,
          components: components,
        ),
      );
    } on FormatException catch (error) {
      setState(() => _error = error.message);
    }
  }

  /// Scroll y restricciones de ancho mantienen visibles las acciones con teclado.
  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    insetPadding: const EdgeInsets.all(16),
    title: Text(
      widget.initial == null ? 'Nueva plantilla' : 'Editar plantilla',
    ),
    content: SizedBox(
      width: 560,
      child: MetaTemplateEditorFields(
        name: _name,
        language: _language,
        body: _body,
        components: _components,
        editing: widget.initial != null,
        category: _category,
        advanced: _advanced,
        error: _error,
        onAdvanced: _category == 'AUTHENTICATION' ? null : _toggleAdvanced,
        onCategory: (value) {
          if (value == 'AUTHENTICATION' && !_advanced) _toggleAdvanced(true);
          setState(() => _category = value);
        },
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
