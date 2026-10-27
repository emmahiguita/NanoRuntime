import 'package:flutter/material.dart';

import '../../engine/business/meta_template_models.dart';
import '../../engine/business/meta_templates_api.dart';
import 'meta_template_editor_dialog.dart';
import 'meta_templates_connection_dialog.dart';
import 'meta_templates_collection.dart';

part 'meta_templates_actions.dart';

/// Gestiona plantillas reales del WABA; no mezcla las plantillas locales de Nano.
class MetaTemplatesScreen extends StatefulWidget {
  const MetaTemplatesScreen({super.key, this.lineId = 'default'});
  final String lineId;

  @override
  State<MetaTemplatesScreen> createState() => _MetaTemplatesScreenState();
}

class _MetaTemplatesScreenState extends State<MetaTemplatesScreen> {
  late final _api = MetaTemplatesApi(lineId: widget.lineId);
  List<MetaMessageTemplate> _templates = const [];
  bool _loading = true;
  bool _configured = false;
  bool _fetching = false;
  bool _mutating = false;
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
    // Agrupa refrescos: una respuesta antigua no debe pisar la consulta nueva.
    if (!mounted || _fetching) return;
    _fetching = true;
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
      _fetching = false;
      if (mounted) {
        setState(() => _loading = false);
      }
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
            onPressed: _loading || _mutating
                ? null
                : () async {
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
            onPressed: _loading || _mutating ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: _configured
          ? FloatingActionButton.extended(
              onPressed: _loading || _mutating ? null : () => _edit(),
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
