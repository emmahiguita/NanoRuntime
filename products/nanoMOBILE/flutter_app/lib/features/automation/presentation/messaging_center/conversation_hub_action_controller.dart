/// Acciones reales del centro de conversaciones de Nano.
///
/// Archiva, limpia memoria persistida y quita la notificación activa. Ninguna
/// acción declara modificar el historial interno de WhatsApp.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/automation_coordinator_provider.dart';
import '../../engine/agent_dependencies.dart';
import '../../engine/messaging/conversation_agent.dart';
import '../../engine/messaging/conversation_hub_providers.dart';
import '../../engine/messaging/conversation_key.dart';
import '../../engine/platform/notification_dismiss_client.dart';
import '../../personal_agent/domain/conversation_owner.dart';
import 'messaging_center_providers.dart';
import 'messaging_conversation_keys.dart';

final conversationHubActionControllerProvider =
    Provider<ConversationHubActionController>((ref) {
      return ConversationHubActionController(ref);
    });

final class ConversationHubActionController {
  ConversationHubActionController(this._ref);

  final Ref _ref;

  Future<void> setOwnership(
    ConversationSummaryItem item,
    ConversationOwner owner,
  ) async {
    final keys = messagingConversationKeys(item);
    final store = _ref.read(conversationOwnershipStoreProvider);
    for (final key in keys) {
      await store.setOwner(key, owner);
    }
    if (item.conversationId.isNotEmpty) {
      await store.setOwner(item.conversationId, owner);
    }
    _refresh();
  }

  Future<void> setArchived(
    ConversationSummaryItem item, {
    required bool archived,
  }) async {
    await _ref
        .read(conversationHubArchiveStoreProvider)
        .setArchived(messagingConversationKeys(item), archived: archived);
    _refresh();
  }

  Future<void> clearNanoMemory(ConversationSummaryItem item) async {
    final keys = messagingConversationKeys(item);
    await _dismissPendingReplies(keys);

    final memory = _ref.read(conversationMemoryStoreProvider);
    final known = memory.knownConversationIds();
    for (final conversationId in known) {
      if (keys.contains(canonicalConversationId(conversationId))) {
        await memory.clearConversation(conversationId);
      }
    }
    _refresh();
  }

  Future<void> removeFromNano(ConversationSummaryItem item) async {
    await clearNanoMemory(item);
    await _ref
        .read(conversationHubArchiveStoreProvider)
        .setArchived(messagingConversationKeys(item), archived: false);

    final notificationKey = item.notificationKey?.trim() ?? '';
    if (notificationKey.isNotEmpty) {
      final dismissed = await NotificationDismissClient.instance.dismiss(
        notificationKey,
      );
      if (!dismissed) {
        throw StateError(
          'La memoria se limpió, pero Android no quitó la notificación activa.',
        );
      }
    }
    _refresh();
  }

  /// Transfiere [item] al agente [target] (Personal ↔ Negocios).
  ///
  /// La asignación se persiste en SQLite vía [ConversationAssignmentStore].
  /// El motor la lee EN VIVO al siguiente turno (sin reiniciar): la memoria
  /// de la conversación no se borra — solo el agente que la atiende cambia.
  Future<void> transferAgent(
    ConversationSummaryItem item,
    ConversationAgentId target,
  ) async {
    final keys = messagingConversationKeys(item);
    final store = _ref.read(conversationAssignmentStoreProvider);
    for (final conversationId in keys) {
      await store.transfer(
        conversationId,
        target,
        reason: 'manual-ui',
      );
    }
    _refresh();
  }

  Future<void> _dismissPendingReplies(Set<String> keys) async {
    final pendingStore = _ref.read(pendingReplyStoreProvider);
    final pending = await pendingStore.allPending();
    for (final reply in pending) {
      if (keys.contains(canonicalConversationId(reply.conversationId))) {
        await pendingStore.dismiss(reply.id);
      }
    }
  }

  void _refresh() {
    _ref.read(conversationHubVersionProvider.notifier).state++;
    _ref.invalidate(archivedConversationIdsProvider);
    _ref.invalidate(liveNotificationsProvider);
    _ref.invalidate(allHubConversationsProvider);
  }
}
