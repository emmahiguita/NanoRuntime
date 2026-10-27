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
import '../../engine/messaging/messaging_package.dart';
import '../../engine/platform/notification_dismiss_client.dart';
import '../../personal_agent/domain/conversation_owner.dart';
import 'messaging_center_providers.dart';
import 'messaging_conversation_keys.dart';

final conversationHubActionControllerProvider =
    Provider<ConversationHubActionController>((ref) {
      final controller = ConversationHubActionController(ref);
      ref.onDispose(controller.dispose);
      return controller;
    });

final class ConversationHubActionController {
  ConversationHubActionController(this._ref);

  final Ref _ref;
  bool _disposed = false;

  // El contenedor es dueño del controlador; no actualiza providers al desmontar.
  void dispose() => _disposed = true;

  // Activa y persiste el disparador antes de conceder permiso al bot.
  // Lista y detalle usan el mismo método, sin declarar activación parcial.
  Future<void> ensureWhatsAppReady(String packageName) async {
    if (_disposed) throw StateError('Controlador cerrado');
    if (packageName != MessagingPackage.whatsapp &&
        packageName != MessagingPackage.whatsappBusiness) {
      return;
    }
    final registry = _ref.read(ruleRegistryProvider);
    await registry.load();
    if (_disposed) throw StateError('Controlador cerrado');
    registry.seedWhatsAppRule(packageName);
    await registry.flush();
    if (!registry.isWhatsAppRuleActive(packageName)) {
      throw StateError('La regla de WhatsApp no quedó activa');
    }
  }

  Future<void> setOwnership(
    ConversationSummaryItem item,
    ConversationOwner owner,
  ) async {
    if (_disposed) throw StateError('Controlador cerrado');
    final keys = messagingConversationKeys(item);
    final store = _ref.read(conversationOwnershipStoreProvider);
    await store.load();
    if (owner == ConversationOwner.bot) {
      await ensureWhatsAppReady(item.packageName);
    }
    if (_disposed) throw StateError('Controlador cerrado');
    // Bloquea todos los aliases en memoria antes de esperar SQLite, sin apagar
    // el modelo compartido. Un turno ya en vuelo pierde su autorización.
    final writes = [for (final key in keys) store.setOwner(key, owner)];
    for (final key in keys) {
      _ref.read(turnSupersedeGuardProvider).bump(key);
    }
    try {
      await Future.wait(writes);
      if (owner == ConversationOwner.human) await _dismissPendingReplies(keys);
    } finally {
      _refresh(); // También muestra el cierre seguro si una escritura falla.
    }
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
    // Retira autorización e invalida el turno ANTES de borrar. No se reactiva
    // automáticamente: un mensaje nuevo no debe volver a poblar lo recién limpiado.
    await setOwnership(item, ConversationOwner.human);
    if (_disposed) throw StateError('Controlador cerrado');

    final memory = _ref.read(conversationMemoryStoreProvider);
    await memory.load();
    final known = {...keys, ...memory.knownConversationIds()};
    for (final conversationId in known) {
      if (keys.contains(canonicalConversationId(conversationId))) {
        await memory.clearConversation(conversationId);
      }
    }
    _refresh();
  }

  Future<void> removeFromNano(ConversationSummaryItem item) async {
    final keys = messagingConversationKeys(item);
    final now = DateTime.now().millisecondsSinceEpoch;
    final cutoffMs = item.lastAtMs > now ? item.lastAtMs : now;
    await clearNanoMemory(item);
    if (_disposed) throw StateError('Controlador cerrado');
    await _ref
        .read(conversationHubArchiveStoreProvider)
        .setRemoved(keys, removedAtMs: cutoffMs);

    final notificationKey = item.notificationKey?.trim() ?? '';
    if (notificationKey.isNotEmpty) {
      // QUÉ: Intenta descartar la notificación activa de Android en modo best-effort.
      // CÓMO: Ignora el retorno `false` cuando la clave proviene de una fila histórica
      // de SQLite cuya notificación ya no existe en la barra de estado.
      // POR QUÉ: Evita que "Quitar del centro de Nano" falle al quitar chats antiguos.
      try {
        await NotificationDismissClient.instance.dismiss(notificationKey);
      } catch (_) {}
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
    for (final key in keys) {
      _ref.read(turnSupersedeGuardProvider).bump(key);
    }
    await _dismissPendingReplies(keys);
    if (_disposed) throw StateError('Controlador cerrado');
    final store = _ref.read(conversationAssignmentStoreProvider);
    for (final conversationId in keys) {
      await store.transfer(conversationId, target, reason: 'manual-ui');
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
    if (_disposed) return;
    _ref.read(conversationHubVersionProvider.notifier).state++;
    _ref.invalidate(archivedConversationIdsProvider);
    _ref.invalidate(removedConversationIdsProvider);
    _ref.invalidate(liveNotificationsProvider);
    _ref.invalidate(allHubConversationsProvider);
  }
}
