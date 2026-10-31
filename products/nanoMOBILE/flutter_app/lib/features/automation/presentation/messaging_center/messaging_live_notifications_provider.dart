/// Adaptación de notificaciones Android activas al modelo del centro de mensajes.
///
/// - QUÉ HACE: Transforma notificaciones activas del sistema en [ConversationSummaryItem].
/// - CÓMO FUNCIONA: Consulta [notificationExecutorProvider], filtra difusiones y reacciones a estados
///   con [WhatsAppStatusClassifier] y unifica la lista con [MessagingDedupMerger].
/// - POR QUÉ: Evita que me gustas/reacciones a historias de WhatsApp se conviertan en chats (<200 líneas).
library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/settings_provider.dart';
import '../../../../core/services/nano_runtime_api.dart';
import '../../application/automation_coordinator_provider.dart';
import '../../engine/messaging/conversation_agent.dart';
import '../../engine/messaging/canonical_message.dart';
import '../../engine/messaging/canonical_message_store.dart';
import '../../engine/messaging/notification_canonical_mapper.dart';
import '../../engine/messaging/conversation_group_resolver.dart';
import '../../engine/messaging/conversation_hub_providers.dart';
import '../../engine/messaging/conversation_key.dart';
import '../../engine/platform/whatsapp_status_classifier.dart';
import '../../executors/device_notification.dart';
import '../../executors/notification_executor_provider.dart';
import '../../personal_agent/application/conversation_ownership_policy.dart';
import '../../personal_agent/application/conversation_ownership_store.dart';
import 'messaging_dedup_merger.dart';

part 'messaging_live_summary.dart';

final liveNotificationStreamProvider =
    StreamProvider.autoDispose<Map<dynamic, dynamic>>((ref) {
      return NanoRuntimeApi.instance.notificationEvents;
    });

final liveNotificationsProvider =
    AutoDisposeAsyncNotifierProvider<
      LiveNotificationsNotifier,
      List<ConversationSummaryItem>
    >(LiveNotificationsNotifier.new);

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
      if (summary != null) {
        items.add(summary);
        _schedulePersistIfChanged(notif, summary);
      }
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
      _schedulePersistIfChanged(notif, summary);
      final current = state.valueOrNull ?? const [];
      final updated = MessagingDedupMerger.deduplicateAndSort([
        summary,
        ...current,
      ]);
      state = AsyncData(updated);
    } catch (_) {}
  }

  // Cache LRU en memoria para evitar ráfagas de hasta 100 llamadas MethodChannel
  // cuando el provider se reconstruye con las mismas 50 notificaciones activas.
  final Map<String, String> _persistedSignatures = <String, String>{};

  void _schedulePersistIfChanged(
    DeviceNotification notif,
    ConversationSummaryItem summary,
  ) {
    final key = notif.key.isNotEmpty ? notif.key : summary.conversationId;
    final signature =
        '${notif.messageTimestamp}|${notif.rawMessages.length}|${summary.lastAtMs}|${summary.lastMessage}';
    if (_persistedSignatures[key] == signature) return;
    _persistedSignatures.remove(key);
    _persistedSignatures[key] = signature;
    if (_persistedSignatures.length > 256) {
      _persistedSignatures.remove(_persistedSignatures.keys.first);
    }
    unawaited(_persistNotification(notif, summary, key, signature));
  }

  Future<void> _persistNotification(
    DeviceNotification notification,
    ConversationSummaryItem summary,
    String cacheKey,
    String signature,
  ) async {
    try {
      // `live:` identifica la tarjeta, no el chat persistente leído por el modelo.
      final conversationId = canonicalConversationId(summary.conversationId);
      // Guarda cada mensaje individual: una notificación puede contener varios
      // entrantes y salientes. La clave Android solo es metadato del contenedor.
      for (final message in NotificationCanonicalMapper.map(
        notification,
        conversationId,
      )) {
        final inserted = await canonicalMessageStore.upsert(message);
        if (!inserted) continue; // Replay ya persistido: evita otra escritura.
        await canonicalMessageStore.recordCoverage(
          conversationId: conversationId,
          provider: CanonicalMessageProvider.androidNotification,
          fromMs: message.occurredAtMs,
          toMs: message.occurredAtMs,
          gapBefore: true,
        );
      }
    } catch (error) {
      if (_persistedSignatures[cacheKey] == signature) {
        _persistedSignatures.remove(cacheKey);
      }
      // Esta tarea vive fuera del build: captura su error sin exponer contenido.
      debugPrint(
        '[canonical:android] fallo de persistencia: ${error.runtimeType}',
      );
    }
  }
}
