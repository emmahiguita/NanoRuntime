import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/settings_provider.dart';
import '../../application/automation_coordinator_provider.dart';
import '../../engine/messaging/conversation_agent.dart';
import '../../engine/messaging/conversation_hub_providers.dart';
import '../../personal_agent/application/conversation_ownership_policy.dart';
import '../../personal_agent/domain/conversation_owner.dart';
import '../widgets/nano_glass_dialog.dart';
import 'conversation_hub_action_controller.dart';

part 'messaging_conversation_actions_view.part.dart';

enum _ConversationAction {
  toggleBot,
  archive,
  unarchive,
  clearMemory,
  remove,
  transferAgent,
}

// El Future de cada menú es su dueño. finally libera la clave incluso al cerrar
// la pantalla o fallar una escritura; no hay timers ni listeners globales.
final _openConversationMenus = <String>{};

/// Menú local de WhatsApp: no modifica conversaciones remotas ni envía mensajes.
Future<void> showMessagingConversationActions(
  BuildContext context,
  WidgetRef ref,
  ConversationSummaryItem item, {
  required bool isArchived,
  ConversationAgentId? currentAgent,
}) async {
  final key = item.conversationId;
  if (!_openConversationMenus.add(key)) return;
  try {
    // Captura dependencias antes de esperar: WidgetRef deja de ser válido al cerrar.
    final controller = ref.read(conversationHubActionControllerProvider);
    final settings = ref.read(settingsProvider);
    final store = ref.read(conversationOwnershipStoreProvider);
    await store.load();
    if (!context.mounted) return;
    final ownership = ConversationOwnershipPolicy.ownershipForConversation(
      store: store,
      conversationId: key,
      packageName: item.packageName,
      isGroup: item.isGroup,
      aliases: item.conversationAliases,
    );
    final active = !ConversationOwnershipPolicy.humanOwns(
      targetContactsMode: settings.waTargetContactsMode,
      ownership: ownership,
    );
    final agent = currentAgent ?? item.agentId;
    final target = agent == ConversationAgentId.personal
        ? ConversationAgentId.business
        : ConversationAgentId.personal;
    final action = await showModalBottomSheet<_ConversationAction>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      constraints: const BoxConstraints(maxWidth: 560),
      sheetAnimationStyle: MediaQuery.disableAnimationsOf(context)
          ? AnimationStyle.noAnimation
          : const AnimationStyle(
              duration: Duration(milliseconds: 180),
              reverseDuration: Duration(milliseconds: 140),
            ),
      builder: (_) => _ConversationActionsMenu(
        item: item,
        active: active,
        archived: isArchived,
        agent: agent,
        target: target,
        blur: settings.glassEnabled
            ? settings.glassBlur.clamp(0, 12).toDouble()
            : 0,
      ),
    );
    if (action == null || !context.mounted) return;
    if (action == _ConversationAction.clearMemory ||
        action == _ConversationAction.remove) {
      if (!await _confirmDestructive(context, action) || !context.mounted) {
        return;
      }
    }
    // El controlador persiste la acción; el menú no se mantiene vivo por la tarea.
    final text = switch (action) {
      _ConversationAction.toggleBot =>
        await controller
            .setOwnership(
              item,
              active ? ConversationOwner.human : ConversationOwner.bot,
            )
            .then(
              (_) => active
                  ? 'Nano pausado en este chat.'
                  : 'Nano activado en este chat.',
            ),
      _ConversationAction.archive =>
        await controller
            .setArchived(item, archived: true)
            .then((_) => 'Conversación archivada en Nano.'),
      _ConversationAction.unarchive =>
        await controller
            .setArchived(item, archived: false)
            .then((_) => 'Conversación desarchivada.'),
      _ConversationAction.clearMemory =>
        await controller
            .clearNanoMemory(item)
            .then((_) => 'Memoria local eliminada. Nano queda pausado.'),
      _ConversationAction.remove =>
        await controller
            .removeFromNano(item)
            .then((_) => 'Conversación quitada de Nano.'),
      _ConversationAction.transferAgent =>
        await controller
            .transferAgent(item, target)
            .then((_) => 'Agente cambiado a ${target.displayName}.'),
    };
    if (context.mounted) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
      );
    }
  } catch (_) {
    // No expone excepciones internas ni afirma éxito si falla almacenamiento.
    if (context.mounted) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text('No se pudo completar la acción. Intenta de nuevo.'),
        ),
      );
    }
  } finally {
    _openConversationMenus.remove(key);
  }
}

/// Cada botón cierra el Navigator del diálogo, nunca la pantalla que lo abrió.
Future<bool> _confirmDestructive(
  BuildContext context,
  _ConversationAction action,
) async {
  final remove = action == _ConversationAction.remove;
  return await NanoGlassDialog.show<bool>(
        context: context,
        title: remove ? '¿Quitar de Nano?' : '¿Limpiar memoria?',
        content: Text(
          remove
              ? 'Nano quedará pausado y se quitará este chat del centro. WhatsApp no se modifica.'
              : 'Nano quedará pausado y se borrará su contexto local. WhatsApp no se modifica.',
        ),
        icon: remove
            ? Icons.delete_sweep_rounded
            : Icons.cleaning_services_rounded,
        iconColor: Theme.of(context).colorScheme.error,
        actionsBuilder: (dialogContext) => [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(remove ? 'Quitar' : 'Limpiar y pausar'),
          ),
        ],
      ) ??
      false;
}
