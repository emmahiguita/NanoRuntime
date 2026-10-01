/// Hoja Material 3 con acciones explícitas para una conversación del hub.
///
/// Los textos distinguen datos locales de Nano y datos internos de WhatsApp
/// para impedir que una acción local parezca una operación remota simulada.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../engine/messaging/conversation_agent.dart';
import '../../engine/messaging/conversation_hub_providers.dart';
import 'conversation_hub_action_controller.dart';

enum _ConversationAction { archive, unarchive, clearMemory, remove, transferAgent }

Future<void> showMessagingConversationActions(
  BuildContext context,
  WidgetRef ref,
  ConversationSummaryItem item, {
  required bool isArchived,
  ConversationAgentId? currentAgent,
}) async {
  final target = currentAgent == ConversationAgentId.business
      ? ConversationAgentId.personal
      : ConversationAgentId.business;
  final targetLabel = target.displayName;
  final currentLabel = currentAgent?.displayName ?? '…';

  final action = await showModalBottomSheet<_ConversationAction>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    builder: (sheetContext) => SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Agente actual ─────────────────────────────────────────────
          ListTile(
            leading: const Icon(Icons.smart_toy_rounded),
            title: Row(
              children: [
                const Text('Agente: '),
                Chip(
                  label: Text(
                    currentLabel,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ],
            ),
            subtitle: Text('Cambiar a → $targetLabel'),
            onTap: () => Navigator.pop(
              sheetContext,
              _ConversationAction.transferAgent,
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: Icon(
              isArchived ? Icons.unarchive_rounded : Icons.archive_rounded,
            ),
            title: Text(
              isArchived ? 'Desarchivar en Nano' : 'Archivar en Nano',
            ),
            subtitle: const Text(
              'Organiza la lista local; no cambia WhatsApp.',
            ),
            onTap: () => Navigator.pop(
              sheetContext,
              isArchived
                  ? _ConversationAction.unarchive
                  : _ConversationAction.archive,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.cleaning_services_rounded),
            title: const Text('Limpiar memoria de Nano'),
            subtitle: const Text('Borra el contexto aprendido de este chat.'),
            onTap: () =>
                Navigator.pop(sheetContext, _ConversationAction.clearMemory),
          ),
          ListTile(
            leading: const Icon(
              Icons.delete_outline_rounded,
              color: Colors.redAccent,
            ),
            title: const Text('Quitar del centro de Nano'),
            subtitle: const Text(
              'Borra memoria local y quita la notificación activa.',
            ),
            onTap: () =>
                Navigator.pop(sheetContext, _ConversationAction.remove),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
  if (action == null || !context.mounted) return;

  if (action == _ConversationAction.clearMemory ||
      action == _ConversationAction.remove) {
    final confirmed = await _confirmDestructiveAction(context, action);
    if (!confirmed || !context.mounted) return;
  }

  final controller = ref.read(conversationHubActionControllerProvider);
  try {
    final message = switch (action) {
      _ConversationAction.archive => _archive(controller, item, true),
      _ConversationAction.unarchive => _archive(controller, item, false),
      _ConversationAction.clearMemory => _clear(controller, item),
      _ConversationAction.remove => _remove(controller, item),
      _ConversationAction.transferAgent =>
        _transfer(controller, item, target),
    };
    final text = await message;
    if (context.mounted) _showMessage(context, text);
  } catch (error) {
    if (context.mounted) {
      _showMessage(context, 'No se completó la acción: $error');
    }
  }
}

Future<String> _archive(
  ConversationHubActionController controller,
  ConversationSummaryItem item,
  bool archived,
) async {
  await controller.setArchived(item, archived: archived);
  return archived
      ? 'Conversación archivada en Nano.'
      : 'Conversación desarchivada.';
}

Future<String> _clear(
  ConversationHubActionController controller,
  ConversationSummaryItem item,
) async {
  await controller.clearNanoMemory(item);
  return 'Memoria local de la conversación eliminada.';
}

Future<String> _remove(
  ConversationHubActionController controller,
  ConversationSummaryItem item,
) async {
  await controller.removeFromNano(item);
  return 'Conversación quitada del centro de Nano.';
}

Future<String> _transfer(
  ConversationHubActionController controller,
  ConversationSummaryItem item,
  ConversationAgentId target,
) async {
  await controller.transferAgent(item, target);
  return 'Agente cambiado a ${target.displayName}. Activo en el próximo mensaje.';
}

Future<bool> _confirmDestructiveAction(
  BuildContext context,
  _ConversationAction action,
) async {
  final remove = action == _ConversationAction.remove;
  return await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(remove ? '¿Quitar de Nano?' : '¿Limpiar memoria?'),
          content: Text(
            remove
                ? 'Se borrará el contexto local y se quitará la notificación activa. El chat seguirá en WhatsApp.'
                : 'Se borrará el historial que Nano usa como contexto. Los mensajes seguirán en WhatsApp.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(remove ? 'Quitar' : 'Limpiar'),
            ),
          ],
        ),
      ) ??
      false;
}

void _showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
