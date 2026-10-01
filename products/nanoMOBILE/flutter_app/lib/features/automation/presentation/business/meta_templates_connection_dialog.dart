import 'package:flutter/material.dart';

import '../../engine/business/meta_templates_api.dart';

/// Configura Nano Gateway; nunca solicita ni guarda el token de Meta en el móvil.
class MetaTemplatesConnectionDialog extends StatefulWidget {
  const MetaTemplatesConnectionDialog({super.key, required this.api});
  final MetaTemplatesApi api;

  static Future<bool> show(BuildContext context, MetaTemplatesApi api) async =>
      await showDialog<bool>(
        context: context,
        builder: (_) => MetaTemplatesConnectionDialog(api: api),
      ) ??
      false;

  @override
  State<MetaTemplatesConnectionDialog> createState() =>
      _ConnectionDialogState();
}

class _ConnectionDialogState extends State<MetaTemplatesConnectionDialog> {
  final _endpoint = TextEditingController();
  final _key = TextEditingController();
  String? _error;
  bool _saving = false;
  bool _useCloud = false;

  /// Carga solo el endpoint guardado; la llave nunca se muestra nuevamente.
  @override
  void initState() {
    super.initState();
    widget.api.connection().then((value) {
      if (mounted) {
        _endpoint.text = value.endpoint;
        setState(() => _useCloud = value.agentUsesCloud);
      }
    });
  }

  /// Libera entradas sensibles y evita controladores colgados.
  @override
  void dispose() {
    _endpoint.dispose();
    _key.dispose();
    super.dispose();
  }

  /// Guarda solo si endpoint HTTPS y llave cumplen las reglas del cliente.
  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.api.configure(
        _endpoint.text,
        _key.text,
        agentUsesCloud: _useCloud,
      );
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error.toString().replaceFirst('FormatException: ', ''),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  /// Explica qué valores vienen del servidor, sin sugerir claves de prueba.
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Conectar WhatsApp Cloud API'),
    content: SizedBox(
      width: 480,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .65,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Configura en el servidor WABA, versión Graph, token, Phone Number ID y llave de Nano. El token nunca se guarda en este teléfono.',
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _endpoint,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  labelText: 'URL HTTPS del servidor Nano',
                ),
              ),
              // El canal local permanece como default; Cloud no tiene fallback silencioso.
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: _useCloud,
                onChanged: _saving
                    ? null
                    : (value) => setState(() => _useCloud = value),
                title: const Text('El agente envía por Meta Cloud'),
                subtitle: const Text(
                  'Requiere consentimiento y ventana/reglas de mensajería de Meta. Si falla, no cambia al canal local.',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _key,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Llave de acceso de Nano',
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: _saving ? null : () => Navigator.pop(context, false),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: _saving ? null : _save,
        child: Text(_saving ? 'Guardando…' : 'Guardar conexión'),
      ),
    ],
  );
}
