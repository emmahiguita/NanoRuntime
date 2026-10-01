import 'package:flutter/material.dart';

import '../../engine/business/meta_template_models.dart';
import '../../engine/business/meta_templates_api.dart';
import 'meta_template_editor_dialog.dart';
import 'meta_templates_connection_dialog.dart';
import 'meta_templates_collection.dart';

/// Gestiona plantillas reales del WABA; no mezcla las plantillas locales de Nano.
class MetaTemplatesScreen extends StatefulWidget {
  const MetaTemplatesScreen({super.key});

  @override
  State<MetaTemplatesScreen> createState() => _MetaTemplatesScreenState();
}

class _MetaTemplatesScreenState extends State<MetaTemplatesScreen> {
  final _api = MetaTemplatesApi();
  List<MetaMessageTemplate> _templates = const [];
  bool _loading = true;
  bool _configured = false;
  String? _error;

  /// Al entrar consulta configuración y datos actuales del proveedor oficial.
  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Al salir cierra HTTPClient para soltar sockets.
  @override
  void dispose() {
    _api.dispose();
    super.dispose();
  }

  /// Lista solo resultados devueltos por Cloud API; errores nunca se ocultan.
  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final connection = await _api.connection();
      final templates = connection.ready
          ? await _api.listTemplates()
          : <MetaMessageTemplate>[];
      if (mounted) {
        setState(() {
          _configured = connection.ready;
          _templates = templates;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  /// Abre el editor con los campos devueltos por Meta y persiste vía gateway.
  Future<void> _edit([MetaMessageTemplate? template]) async {
    final draft = await showDialog<MetaMessageTemplateDraft>(
      context: context,
      builder: (_) => MetaTemplateEditorDialog(initial: template),
    );
    if (draft == null) return;
    try {
      if (template == null) {
        await _api.create(draft);
      } else {
        await _api.update(template, draft);
      }
      await _load();
      if (mounted) {
        _notice(
          template == null
              ? 'Meta recibió la plantilla; el estado aparecerá al actualizar.'
              : 'Meta recibió la edición; actualiza para consultar su estado.',
        );
      }
    } catch (error) {
      if (mounted) _notice(error.toString().replaceFirst('Exception: ', ''));
    }
  }

  /// Confirma una eliminación irreversible antes de llamar al recurso remoto.
  Future<void> _delete(MetaMessageTemplate template) async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar plantilla en Meta'),
        content: Text(
          'Se eliminará “${template.name}” de la cuenta conectada.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (approved != true) {
      return;
    }
    try {
      await _api.delete(template);
      await _load();
      if (mounted) _notice('Meta confirmó la solicitud de eliminación.');
    } catch (error) {
      if (mounted) _notice(error.toString().replaceFirst('Exception: ', ''));
    }
  }

  /// Comparte respuestas reales y conserva mensajes concisos para móvil.
  void _notice(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));

  /// Presenta editor, estado de conexión y lista adaptados a portrait/landscape.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Plantillas de WhatsApp'),
        actions: [
          IconButton(
            tooltip: 'Conexión segura',
            onPressed: () async {
              final saved = await MetaTemplatesConnectionDialog.show(
                context,
                _api,
              );
              if (saved && mounted) {
                _load();
              }
            },
            icon: const Icon(Icons.settings_outlined),
          ),
          IconButton(
            tooltip: 'Actualizar desde Meta',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: _configured
          ? FloatingActionButton.extended(
              onPressed: _loading ? null : () => _edit(),
              icon: const Icon(Icons.add),
              label: const Text('Nueva plantilla'),
            )
          : null,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: MetaTemplatesCollection(
            loading: _loading,
            configured: _configured,
            error: _error,
            templates: _templates,
            onConfigure: () async {
              final saved = await MetaTemplatesConnectionDialog.show(
                context,
                _api,
              );
              if (saved && mounted) {
                _load();
              }
            },
            onRefresh: _load,
            onEdit: _edit,
            onDelete: _delete,
          ),
        ),
      ),
    );
  }
}
