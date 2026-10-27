import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../engine/business/business_facts_providers.dart';
import '../../engine/business/business_response_templates.dart';
import 'business_sales_message_fields.dart';

/// Editor móvil de frases reales que consume BusinessConversationResolver.
class BusinessSalesMessagesEditor extends ConsumerStatefulWidget {
  const BusinessSalesMessagesEditor({super.key});

  @override
  ConsumerState<BusinessSalesMessagesEditor> createState() =>
      _BusinessSalesMessagesEditorState();
}

class _BusinessSalesMessagesEditorState
    extends ConsumerState<BusinessSalesMessagesEditor> {
  static const _fields = businessSalesMessageFields;
  bool _loading = true, _saving = false;

  final Map<String, TextEditingController> _controllers = {};

  /// Carga override guardado o el texto actual que ya usa el agente como inicio editable.
  @override
  void initState() {
    super.initState();
    for (final field in _fields) {
      _controllers[field.key] = TextEditingController();
    }
    _hydrate();
  }

  /// Espera SQLite antes de permitir editar: el estado inicial del provider
  /// todavía puede estar vacío aunque existan frases guardadas del propietario.
  Future<void> _hydrate() async {
    await ref.read(businessFactsNotifierProvider.notifier).ready;
    if (!mounted) return;
    final saved = ref
        .read(businessFactsNotifierProvider)
        .responseTemplates
        .phrases;
    for (final field in _fields) {
      _controllers[field.key]!.text =
          saved[field.key] ??
          BusinessResponseTemplates.editorDefaults[field.key] ??
          '';
    }
    setState(() => _loading = false);
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
    if (_loading || _saving) return;
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
    setState(() => _saving = true);
    final saved = await ref
        .read(businessFactsNotifierProvider.notifier)
        .setResponseTemplates(
          BusinessResponseTemplates(phrases: Map.unmodifiable(phrases)),
        );
    if (!mounted) return;
    setState(() => _saving = false);
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
            onPressed: _loading || _saving ? null : _save,
            icon: const Icon(Icons.save_outlined),
            label: Text(_saving ? 'Guardando…' : 'Guardar'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Center(
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
                              Text(
                                field.title,
                                style: theme.textTheme.titleMedium,
                              ),
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
                                textCapitalization:
                                    TextCapitalization.sentences,
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
