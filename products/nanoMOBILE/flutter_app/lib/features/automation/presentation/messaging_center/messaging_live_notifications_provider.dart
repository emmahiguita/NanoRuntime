/// Adaptación de notificaciones Android activas al modelo del centro de mensajes.
///
/// - QUÉ HACE: Transforma notificaciones activas del sistema en [ConversationSummaryItem].
/// - CÓMO FUNCIONA: Consulta [notificationExecutorProvider], filtra difusiones y reacciones a estados
///   con [WhatsAppStatusClassifier] y unifica la lista con [MessagingDedupMerger].
/// - POR QUÉ: Evita que me gustas/reacciones a historias de WhatsApp se conviertan en chats (<200 líneas).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/settings_provider.dart';
import '../../../../core/services/nano_runtime_api.dart';
import '../../application/automation_coordinator_provider.dart';
import '../../engine/messaging/conversation_agent.dart';
import '../../engine/messaging/conversation_group_resolver.dart';
import '../../engine/messaging/conversation_hub_providers.dart';
import '../../engine/messaging/conversation_key.dart';
import '../../engine/platform/whatsapp_status_classifier.dart';
import '../../executors/device_notification.dart';
import '../../executors/notification_executor_provider.dart';
import '../../personal_agent/application/conversation_ownership_policy.dart';
import '../../personal_agent/application/conversation_ownership_store.dart';
import 'messaging_dedup_merger.dart';

final liveNotificationStreamProvider =
    StreamProvider.autoDispose<Map<dynamic, dynamic>>((ref) {
      return NanoRuntimeApi.instance.notificationEvents;
    });

final liveNotificationsProvider = AutoDisposeAsyncNotifierProvider<
    LiveNotificationsNotifier, List<ConversationSummaryItem>>(
  LiveNotificationsNotifier.new,
);

class LiveNotificationsNotifier
    extends AutoDisposeAsyncNotifier<List<ConversationSummaryItem>> {
  @override
  Future<List<ConversationSummaryItem>> build() async {
    final executor = ref.watch(notificationExecutorProvider);
    final settings = ref.watch(settingsProvider);
    final ownershipStore = ref.watch(conversationOwnershipStoreProvider);
    await ownershipStore.load();

    // Reacción incremental instantánea sin bloquear con consultas completas a IPC
    ref.listen<AsyncValue<Map<dynamic, dynamic>>>(
      liveNotificationStreamProvider,
      (prev, next) {
        final rawMap = next.valueOrNull;
        if (rawMap != null && rawMap.isNotEmpty) {
          _handleLiveEvent(rawMap, ownershipStore, settings);
        }
      },
    );

    final status = await executor.status();
    if (!status.connected) return const [];

    final notifications = await executor.list(limit: 50);
    final items = <ConversationSummaryItem>[];
    final now = DateTime.now().millisecondsSinceEpoch;

    for (final notif in notifications) {
      final summary = _buildSummary(notif, ownershipStore, settings, now);
      if (summary != null) items.add(summary);
    }

    return MessagingDedupMerger.deduplicateAndSort(items);
  }

  void _handleLiveEvent(
    Map<dynamic, dynamic> map,
    ConversationOwnershipStore ownershipStore,
    SettingsState settings,
  ) {
    try {
      final notif = DeviceNotification.fromMap(map);
      final now = DateTime.now().millisecondsSinceEpoch;
      final summary = _buildSummary(notif, ownershipStore, settings, now);
      if (summary == null) return;
      final current = state.valueOrNull ?? const [];
      final updated = MessagingDedupMerger.deduplicateAndSort([summary, ...current]);
      state = AsyncData(updated);
    } catch (_) {}
  }
}

ConversationSummaryItem? _buildSummary(
  DeviceNotification notif,
  ConversationOwnershipStore ownershipStore,
  SettingsState settings,
  int now,
) {
  if (!MessagingDedupMerger.isSupportedMessagingApp(notif.packageName)) {
    return null;
  }

  final notifObj = notif.toNotificationObject();
  if (WhatsAppStatusClassifier.shouldIgnoreFromChatHub(notifObj)) {
    return null;
  }

  final identity = resolveConversationIdentity(notifObj);
  final rawConvKey = notif.conversationId.isNotEmpty
      ? notif.conversationId
      : (notif.shortcutId.isNotEmpty
            ? notif.shortcutId
            : '${notif.packageName}:${notif.title}');
  final convKey = identity.key.id.isNotEmpty
      ? identity.key.id
      : rawConvKey;
  final isGroup = ConversationGroupResolver.isGroup(
    convId: rawConvKey,
    isGroupFlag: notif.isGroup,
    rawTitle: notif.title.isNotEmpty ? notif.title : null,
    conversationTitle: notif.conversationTitle.isNotEmpty
        ? notif.conversationTitle
        : null,
    shortcutId: notif.shortcutId.isNotEmpty ? notif.shortcutId : null,
  );
  final groupInfo = isGroup
      ? ConversationGroupResolver.resolveGroupInfo(
          convId: rawConvKey,
          conversationTitle: notif.conversationTitle.isNotEmpty
              ? notif.conversationTitle
              : null,
          title: notif.title.isNotEmpty ? notif.title : null,
          sender: notif.sender.isNotEmpty ? notif.sender : null,
        )
      : null;

  final groupTitle = groupInfo?.groupTitle;
  final displayName = isGroup
      ? (groupTitle ?? 'Grupo de WhatsApp')
      : (notif.sender.isNotEmpty
            ? notif.sender
            : (notif.title.isNotEmpty ? notif.title : 'Chat'));
  final lastSender = isGroup
      ? (groupInfo?.lastSender.isNotEmpty == true
            ? groupInfo!.lastSender
            : (notif.sender.isNotEmpty ? notif.sender : null))
      : (notif.sender.isNotEmpty ? notif.sender : null);
  final agentId = notif.packageName == 'com.whatsapp.w4b'
      ? ConversationAgentId.business
      : ConversationAgentId.personal;
  final messageText = notif.messageText.isNotEmpty
      ? notif.messageText
      : (notif.text.isNotEmpty ? notif.text : '');

  final lowerName = displayName.trim().toLowerCase();
  final lowerMsg = messageText.trim().toLowerCase();
  if (displayName == '0' ||
      lowerName == 'actualizaciones de estado' ||
      lowerName == 'status updates' ||
      lowerName == 'actualizaciones' ||
      lowerName == 'novedades' ||
      lowerName.contains('comprobando si hay') ||
      lowerName.contains('buscando mensajes nuevos')) {
    return null;
  }
  if (lowerMsg.contains('le gustó tu estado') ||
      lowerMsg.contains('le gusta tu estado') ||
      lowerMsg.contains('dio me gusta a tu estado') ||
      lowerMsg.contains('reacted to your status') ||
      lowerMsg.contains('replied to your status') ||
      lowerMsg.contains('comprobando si hay') ||
      lowerMsg.contains('buscando mensajes nuevos')) {
    return null;
  }

  final atMs = notif.messageTimestamp > 0
      ? notif.messageTimestamp
      : (notif.postedAt.millisecondsSinceEpoch > 0
            ? notif.postedAt.millisecondsSinceEpoch
            : now);

  return ConversationSummaryItem(
    conversationId: 'live:$convKey',
    displayName: displayName,
    packageName: notif.packageName,
    lastMessage: messageText,
    lastAtMs: atMs,
    hasPendingReply: false,
    humanOwns: ConversationOwnershipPolicy.humanOwns(
      targetContactsMode: settings.waTargetContactsMode,
      ownership: ConversationOwnershipPolicy.ownershipForNotification(
        store: ownershipStore,
        conversationId: convKey,
        notification: notifObj,
        isGroup: isGroup,
      ),
    ),
    agentId: agentId,
    entryCount: 1,
    notificationKey: notif.key,
    isGroup: isGroup,
    groupTitle: groupTitle,
    lastSender: lastSender,
  );
}
