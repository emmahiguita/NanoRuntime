import 'package:flutter/material.dart';
import '../../engine/business/meta_inbox_controller.dart';
import '../../engine/business/meta_inbox_models.dart';

/// Lista oficial con historial anterior y estados vacíos honestos; sin botones de envío ficticios.
class MetaInboxList extends StatelessWidget {
  const MetaInboxList({
    super.key,
    required this.controller,
    required this.onOpen,
    required this.onConfigure,
  });
  final MetaInboxController controller;
  final ValueChanged<String> onOpen;
  final VoidCallback onConfigure;

  /// Material del tema actual: sin colores adicionales ni tamaños ligados a la orientación.
  @override
  Widget build(BuildContext context) {
    final history = controller.peer != null;
    if (!controller.configured && !controller.busy) {
      return _Empty(
        text:
            'Conecta el servidor HTTPS de Nano para consultar mensajes oficiales.',
        action: 'Configurar conexión',
        onAction: onConfigure,
      );
    }
    if (controller.messages.isEmpty) {
      if (controller.busy) {
        return const Center(child: CircularProgressIndicator());
      }
      return _Empty(
        text:
            controller.error ??
            'No hay mensajes recibidos guardados en esta bandeja.',
        action: 'Actualizar',
        onAction: () => controller.refresh(),
      );
    }
    return RefreshIndicator(
      onRefresh: controller.refresh,
      child: ListView.builder(
        reverse: history,
        padding: const EdgeInsets.all(12),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: controller.messages.length + 1,
        itemBuilder: (context, index) {
          if (index == controller.messages.length) {
            return Padding(
              padding: const EdgeInsets.all(8),
              child: controller.nextBefore == null
                  ? const Text(
                      'Fin del historial recibido disponible',
                      textAlign: TextAlign.center,
                    )
                  : Center(
                      child: TextButton(
                        onPressed: controller.busy
                            ? null
                            : () => controller.loadOlder(),
                        child: const Text('Cargar anteriores'),
                      ),
                    ),
            );
          }
          final message = controller.messages[index];
          return history
              ? _Message(message: message)
              : Card(
                  key: ValueKey(message.peerId),
                  elevation: 0,
                  child: ListTile(
                    leading: const Icon(Icons.chat_bubble_outline),
                    title: Text('+ ${message.peerId}'),
                    subtitle: Text(
                      message.preview,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => onOpen(message.peerId),
                  ),
                );
        },
      ),
    );
  }
}

/// El timestamp procede de Meta; nunca usa la hora de hoy para rellenar mensajes antiguos.
class _Message extends StatelessWidget {
  const _Message({required this.message});
  final MetaInboxMessage message;
  String _status(String value) => switch (value) {
    'accepted' => 'Aceptado por Meta',
    'sent' => 'Enviado',
    'delivered' => 'Entregado',
    'read' => 'Le?do',
    'failed' => 'Fallido',
    _ => 'Estado no disponible',
  };
  @override
  Widget build(BuildContext context) {
    final time = message.providerTime;
    final local = MaterialLocalizations.of(context);
    final date = time == null
        ? 'Fecha no disponible'
        : '${local.formatCompactDate(time)} · ${local.formatTimeOfDay(TimeOfDay.fromDateTime(time))}';
    return Align(
      key: ValueKey(message.wamid),
      alignment: message.isOutbound
          ? Alignment.centerRight
          : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Card(
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.isOutbound ? 'Tu negocio' : 'Contacto',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                SelectableText(message.preview),
                if (message.deliveryState.isNotEmpty)
                  Text(_status(message.deliveryState)),
                const SizedBox(height: 8),
                Text(date, style: Theme.of(context).textTheme.labelSmall),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Texto desplazable evita overflow en horizontal o con letras grandes.
class _Empty extends StatelessWidget {
  const _Empty({
    required this.text,
    required this.action,
    required this.onAction,
  });
  final String text, action;
  final VoidCallback onAction;
  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(text, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          TextButton(onPressed: onAction, child: Text(action)),
        ],
      ),
    ),
  );
}
