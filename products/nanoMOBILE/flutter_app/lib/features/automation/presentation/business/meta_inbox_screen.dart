import 'package:flutter/material.dart';
import '../../engine/business/meta_inbox_controller.dart';
import 'meta_templates_connection_dialog.dart';
import 'meta_inbox_list.dart';

/// Bandeja de recepción oficial, separada de WhatsApp Web y del listener de notificaciones.
class MetaInboxScreen extends StatefulWidget {
  const MetaInboxScreen({super.key, this.peer});
  final String? peer;
  @override
  State<MetaInboxScreen> createState() => _MetaInboxScreenState();
}

class _MetaInboxScreenState extends State<MetaInboxScreen>
    with WidgetsBindingObserver {
  late final MetaInboxController _controller;

  /// El controlador pertenece a esta ruta; no añade un servicio residente al teléfono.
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = MetaInboxController(
      peer: widget.peer,
      isVisible: () => mounted && ModalRoute.of(context)?.isCurrent == true,
    );
    _controller.refresh();
  }

  /// Pausa consultas en background; el webhook permanece en el servidor, no en Android.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _controller.setActive(state == AppLifecycleState.resumed);
  }

  /// Reutiliza configuración segura existente: no solicita el token de Meta.
  Future<void> _configure() async {
    _controller.setActive(false);
    try {
      final saved = await MetaTemplatesConnectionDialog.show(
        context,
        _controller.api,
      );
      if (saved && mounted) await _controller.refresh();
    } finally {
      if (mounted) _controller.setActive(true);
    }
  }

  /// Interlocutores se abren por ID exacto, sin coincidencias aproximadas de nombres.
  void _open(String peer) => Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => MetaInboxScreen(peer: peer)));

  /// Tema Material de Nano y ancho limitado mantienen la lectura en vertical/horizontal.
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, _) => Scaffold(
      appBar: AppBar(
        title: Text(
          widget.peer == null ? 'WhatsApp oficial' : '+ ${widget.peer}',
        ),
        actions: [
          if (widget.peer == null)
            IconButton(
              tooltip: 'Conexión segura',
              onPressed: _controller.busy ? null : _configure,
              icon: const Icon(Icons.settings_outlined),
            ),
          IconButton(
            tooltip: 'Actualizar historial',
            onPressed: _controller.busy ? null : () => _controller.refresh(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Text(
                    'Mensajes recibidos y guardados por el webhook oficial. '
                    'No incluye todavía el texto de envíos salientes.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                if (_controller.error != null &&
                    _controller.messages.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      _controller.error!,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                Expanded(
                  child: MetaInboxList(
                    controller: _controller,
                    onOpen: _open,
                    onConfigure: _configure,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  /// Libera observador, timer y sockets antes de destruir el widget.
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }
}
