import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../engine/business/business_facts_providers.dart';
import '../../engine/business/business_response_templates.dart';

/// Editor móvil de frases reales que consume BusinessConversationResolver.
class BusinessSalesMessagesEditor extends ConsumerStatefulWidget {
  const BusinessSalesMessagesEditor({super.key});

  @override
  ConsumerState<BusinessSalesMessagesEditor> createState() =>
      _BusinessSalesMessagesEditorState();
}

class _BusinessSalesMessagesEditorState
    extends ConsumerState<BusinessSalesMessagesEditor> {
  static const _fields = <({String key, String title, String help})>[
    (
      key: BusinessResponseTemplates.greeting,
      title: 'Saludo',
      help: '{negocio}',
    ),
    (
      key: BusinessResponseTemplates.greetingPrefix,
      title: 'Saludo con consulta',
      help: '{negocio}',
    ),
    (
      key: BusinessResponseTemplates.productMatch,
      title: 'Respuesta de producto',
      help: '{productos}',
    ),
    (
      key: BusinessResponseTemplates.productCatalog,
      title: 'Respuesta de catálogo',
      help: '{productos}',
    ),
    (
      key: BusinessResponseTemplates.salesClosing,
      title: 'Cierre comercial',
      help: 'Sin variables',
    ),
    (
      key: BusinessResponseTemplates.humanHandoff,
      title: 'Pase a un asesor',
      help: 'Sin variables',
    ),
    (
      key: BusinessResponseTemplates.missingFacts,
      title: 'Dato aún no configurado',
      help: '{datos}',
    ),
    (
      key: BusinessResponseTemplates.unknownMessage,
      title: 'Consulta no entendida',
      help: '{motivo}',
    ),
  ];

  final Map<String, TextEditingController> _controllers = {};

  /// Carga override guardado o el texto actual que ya usa el agente como inicio editable.
  @override
  void initState() {
    super.initState();
    final saved = ref
        .read(businessFactsNotifierProvider)
        .responseTemplates
        .phrases;
    for (final field in _fields) {
      _controllers[field.key] = TextEditingController(
        text:
            saved[field.key] ??
            BusinessResponseTemplates.editorDefaults[field.key],
      );
    }
  }

  /// Libera los controladores cuando se abandona el editor.
  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  /// Valida variables conocidas y guarda en la sección SQLite del negocio.
  Future<void> _save() async {
    final phrases = {
      for (final field in _fields)
        field.key: _controllers[field.key]!.text.trim(),
    };
    for (final entry in phrases.entries) {
      if (entry.value.isEmpty) return _notice('Cada frase debe tener texto.');
      final invalid = const BusinessResponseTemplates().invalidVariables(
        entry.key,
        entry.value,
      );
      if (invalid.isNotEmpty) {
        return _notice('Variable no disponible: {${invalid.first}}');
      }
    }
    final saved = await ref
        .read(businessFactsNotifierProvider.notifier)
        .setResponseTemplates(
          BusinessResponseTemplates(phrases: Map.unmodifiable(phrases)),
        );
    if (!mounted) return;
    if (saved) {
      Navigator.of(context).pop();
    } else {
      _notice('No se pudieron guardar los cambios.');
    }
  }

  /// Presenta errores de validación y persistencia sin ocultarlos.
  void _notice(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));

  /// Organiza las frases como campos multilinea legibles en vertical u horizontal.
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Frases del agente de ventas'),
        actions: [
          TextButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save_outlined),
            label: const Text('Guardar'),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Personaliza cómo habla Nano. Los datos de productos, precios y operación siguen viniendo del negocio; aquí solo cambias la redacción.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              for (final field in _fields) ...[
                Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(field.title, style: theme.textTheme.titleMedium),
                        const SizedBox(height: 4),
                        Text(
                          'Variable disponible: ${field.help}',
                          style: theme.textTheme.bodySmall,
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _controllers[field.key],
                          minLines: 2,
                          maxLines: 5,
                          textCapitalization: TextCapitalization.sentences,
                          style: theme.textTheme.bodyLarge,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            alignLabelWithHint: true,
                            labelText: 'Texto que usará el agente',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
