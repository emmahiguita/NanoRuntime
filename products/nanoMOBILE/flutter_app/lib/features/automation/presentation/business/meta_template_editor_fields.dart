import 'package:flutter/material.dart';

/// Campos de presentación sin HTTP ni persistencia: el estado vive en el editor.
/// Se desplazan dentro del diálogo; no fijan alturas que desborden en horizontal.
class MetaTemplateEditorFields extends StatelessWidget {
  const MetaTemplateEditorFields({
    super.key,
    required this.name,
    required this.language,
    required this.body,
    required this.components,
    required this.editing,
    required this.category,
    required this.advanced,
    required this.error,
    required this.onAdvanced,
    required this.onCategory,
  });
  final TextEditingController name, language, body, components;
  final bool editing, advanced;
  final String? category, error;
  final ValueChanged<bool>? onAdvanced;
  final ValueChanged<String?> onCategory;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text(
        'Edita el mensaje y envíalo a revisión. Meta determina su aprobación.',
      ),
      const SizedBox(height: 16),
      TextField(
        controller: name,
        readOnly: editing,
        decoration: const InputDecoration(
          labelText: 'Nombre de plantilla',
          hintText: 'confirmacion_pedido',
        ),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: language,
        readOnly: editing,
        decoration: const InputDecoration(
          labelText: 'Idioma',
          hintText: 'es_CO',
        ),
      ),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        initialValue: category,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Categoría'),
        items: const [
          DropdownMenuItem(value: 'UTILITY', child: Text('Transaccional')),
          DropdownMenuItem(value: 'MARKETING', child: Text('Promocional')),
          DropdownMenuItem(
            value: 'AUTHENTICATION',
            child: Text('Autenticación'),
          ),
        ],
        onChanged: onCategory,
      ),
      const SizedBox(height: 12),
      SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        title: const Text('Edición avanzada'),
        subtitle: const Text('Componentes oficiales, variables y botones'),
        value: advanced,
        onChanged: onAdvanced,
      ),
      if (advanced)
        TextField(
          controller: components,
          minLines: 5,
          maxLines: 12,
          keyboardType: TextInputType.multiline,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          decoration: const InputDecoration(labelText: 'Componentes · JSON'),
        )
      else ...[
        TextField(
          controller: body,
          minLines: 3,
          maxLines: 8,
          keyboardType: TextInputType.multiline,
          decoration: const InputDecoration(
            labelText: 'Cuerpo del mensaje',
            helperText:
                'Las variables requieren ejemplos en los componentes avanzados.',
          ),
        ),
        const SizedBox(height: 12),
        // Solo este bloque se reconstruye al escribir, no todo el diálogo.
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: body,
          builder: (context, value, _) => Card.filled(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Vista previa del cuerpo',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    value.text.isEmpty
                        ? 'Escribe el mensaje para previsualizarlo.'
                        : value.text,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
      if (error != null)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text(
            error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
    ],
  );
}
