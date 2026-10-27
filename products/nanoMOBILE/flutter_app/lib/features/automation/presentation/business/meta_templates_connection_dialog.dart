import 'package:flutter/material.dart';

import '../../engine/business/meta_templates_api.dart';
import 'meta_gateway_key_field.dart';
import 'meta_official_mcp_card.dart';
import '../widgets/dialogs/dialog_container_shell.dart';

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
  final _sendKey = TextEditingController();
  final _adminKey = TextEditingController();
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
    _sendKey.dispose();
    _adminKey.dispose();
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
        sendKey: _sendKey.text,
        adminKey: _adminKey.text,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error.toString().replaceFirst('FormatException: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Explica qué valores vienen del servidor, sin sugerir claves de prueba.
  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final availableHeight =
        media.size.height - media.viewInsets.vertical - media.padding.vertical;
    final dialogHeight = (availableHeight * .86).clamp(420.0, 720.0);

    return DialogContainerShell(
      child: SizedBox(
        width: 480,
        height: dialogHeight,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Conectar WhatsApp Business',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Semantics(
                    label: 'Cerrar',
                    button: true,
                    child: IconButton(
                      onPressed: _saving ? null : () => Navigator.pop(context, false),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Nano Gateway mantiene la automatización activa y recibe webhooks. Sus permisos de lectura, envío y administración son independientes; el token y App Secret de Meta permanecen en el servidor.',
                    ),
                    const SizedBox(height: 14),
                    const MetaOfficialMcpCard(),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _endpoint,
                      keyboardType: TextInputType.url,
                      decoration: const InputDecoration(
                        labelText: 'URL HTTPS de Nano Gateway',
                        helperText: 'Para funcionamiento continuo y webhooks',
                      ),
                    ),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: _useCloud,
                      onChanged: _saving ? null : (value) => setState(() => _useCloud = value),
                      title: const Text('El agente envía por Meta Cloud'),
                      subtitle: const Text(
                        'Requiere consentimiento y ventana/reglas de mensajería de Meta. Si falla, no cambia al canal local.',
                      ),
                    ),
                    const SizedBox(height: 10),
                    MetaGatewayKeyField(controller: _key, label: 'Lectura del Gateway', enabled: !_saving),
                    MetaGatewayKeyField(controller: _sendKey, label: 'Envío (opcional)', enabled: !_saving),
                    MetaGatewayKeyField(controller: _adminKey, label: 'Administrar plantillas (opcional)', enabled: !_saving),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          _error!,
                          style: TextStyle(color: Theme.of(context).colorScheme.error),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _saving ? null : () => Navigator.pop(context, false),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    child: Text(_saving ? 'Guardando…' : 'Guardar conexión'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
