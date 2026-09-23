/// MESSAGING-CENTER-PROVIDERS — Estado reactivo del Centro de Mensajería.
/// QUÉ HACE: Gestiona agregación reactiva, filtrado y conteos sin duplicados ni alucinaciones.
/// CÓMO FUNCIONA: Riverpod streams + [MessagingDedupMerger] para fusionar SQLite con Android.
/// POR QUÉ: Cumple SOLID (SRP) y límite estricto de archivos menores a 200 líneas.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/messaging_platform.dart';
import '../../engine/messaging/conversation_agent.dart';
import '../../engine/messaging/conversation_hub_providers.dart';
import '../../executors/notification_executor.dart';
import '../../executors/notification_executor_provider.dart';
import 'messaging_dedup_merger.dart';
import 'messaging_live_notifications_provider.dart';

export 'messaging_live_notifications_provider.dart';

final selectedPlatformFilterProvider = StateProvider<MessagingPlatform?>(
  (ref) => null,
);
final selectedCategoryTabProvider = StateProvider<MessagingCategoryFilter>(
  (ref) => MessagingCategoryFilter.all,
);
final messagingSearchQueryProvider = StateProvider<String>((ref) => '');

/// Estado de acceso del listener de notificaciones en Android
final notificationAccessProvider =
    FutureProvider.autoDispose<NotificationAccessStatus>((ref) async {
      final executor = ref.watch(notificationExecutorProvider);
      return executor.status();
    });

/// Agrega conversaciones de ambos agentes (personal y negocios) Y notificaciones en vivo.
final allHubConversationsProvider =
    FutureProvider<List<ConversationSummaryItem>>((ref) async {
      ref.watch(liveNotificationStreamProvider);
      ref.watch(conversationHubVersionProvider);

      final personalList = await ref.watch(
        conversationHubListProvider(ConversationAgentId.personal).future,
      );
      final businessList = await ref.watch(
        conversationHubListProvider(ConversationAgentId.business).future,
      );
      final liveList = await ref.watch(liveNotificationsProvider.future);

      return MessagingDedupMerger.deduplicateAndSort([
        ...personalList,
        ...businessList,
        ...liveList,
      ]);
    });

final filteredConversationsProvider =
    Provider<AsyncValue<List<ConversationSummaryItem>>>((ref) {
      final allAsync = ref.watch(allHubConversationsProvider);
      final platform = ref.watch(selectedPlatformFilterProvider);
      final category = ref.watch(selectedCategoryTabProvider);
      final search = ref
          .watch(messagingSearchQueryProvider)
          .trim()
          .toLowerCase();

      return allAsync.whenData((list) {
        return list.where((item) {
          if (platform != null) {
            final itemPlatform = MessagingPlatform.fromPackageName(
              item.packageName,
            );
            if (itemPlatform != platform) return false;
          }
          switch (category) {
            case MessagingCategoryFilter.all ||
                MessagingCategoryFilter.contacts:
              break;
            case MessagingCategoryFilter.groups:
              if (!item.isGroup) return false;
            case MessagingCategoryFilter.unread:
              if (!item.hasPendingReply) return false;
            case MessagingCategoryFilter.personal:
              if (item.agentId != ConversationAgentId.personal) return false;
            case MessagingCategoryFilter.business:
              if (item.agentId != ConversationAgentId.business) return false;
            case MessagingCategoryFilter.bots:
              if (item.humanOwns) return false;
            case MessagingCategoryFilter.archived:
              break;
          }
          if (search.isNotEmpty) {
            final name = item.displayName.toLowerCase();
            final last = item.lastMessage.toLowerCase();
            if (!name.contains(search) && !last.contains(search)) return false;
          }
          return true;
        }).toList();
      });
    });

final platformCountsProvider = Provider<Map<MessagingPlatform, int>>((ref) {
  final all = ref.watch(allHubConversationsProvider).value ?? const [];
  final counts = <MessagingPlatform, int>{};
  for (final platform in MessagingPlatform.values) {
    counts[platform] = all
        .where(
          (c) => MessagingPlatform.fromPackageName(c.packageName) == platform,
        )
        .length;
  }
  return counts;
});

final platformUnreadCountsProvider = Provider<Map<MessagingPlatform, int>>((
  ref,
) {
  final all = ref.watch(allHubConversationsProvider).value ?? const [];
  final counts = <MessagingPlatform, int>{};
  for (final platform in MessagingPlatform.values) {
    counts[platform] = all
        .where(
          (c) =>
              MessagingPlatform.fromPackageName(c.packageName) == platform &&
              c.hasPendingReply,
        )
        .length;
  }
  return counts;
});

final pendingRepliesCountProvider = Provider<int>((ref) {
  final all = ref.watch(allHubConversationsProvider).value ?? const [];
  return all.where((c) => c.hasPendingReply).length;
});

final categoryCountsProvider = Provider<Map<MessagingCategoryFilter, int>>((
  ref,
) {
  final all = ref.watch(allHubConversationsProvider).value ?? const [];
  return {
    MessagingCategoryFilter.all: all.length,
    MessagingCategoryFilter.groups: all.where((c) => c.isGroup).length,
    MessagingCategoryFilter.contacts: 0,
    MessagingCategoryFilter.unread: all.where((c) => c.hasPendingReply).length,
    MessagingCategoryFilter.personal: all
        .where((c) => c.agentId == ConversationAgentId.personal)
        .length,
    MessagingCategoryFilter.business: all
        .where((c) => c.agentId == ConversationAgentId.business)
        .length,
    MessagingCategoryFilter.bots: all.where((c) => !c.humanOwns).length,
    MessagingCategoryFilter.archived: 0,
  };
});
