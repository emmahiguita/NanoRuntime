/// MESSAGING-CENTER-PROVIDERS — Estado reactivo del Centro de Mensajería.
/// QUÉ HACE: Gestiona agregación reactiva, filtrado y conteos sin duplicados ni alucinaciones.
/// CÓMO FUNCIONA: Riverpod streams + [MessagingDedupMerger] para fusionar SQLite con Android.
/// POR QUÉ: Cumple SOLID (SRP) y límite estricto de archivos menores a 200 líneas.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/messaging_platform.dart';
import '../../engine/messaging/conversation_agent.dart';
import '../../engine/messaging/conversation_hub_archive_store.dart';
import '../../engine/messaging/conversation_hub_providers.dart';
import '../../executors/notification_executor.dart';
import '../../executors/notification_executor_provider.dart';
import 'messaging_dedup_merger.dart';
import 'messaging_live_notifications_provider.dart';
import 'messaging_conversation_keys.dart';
import 'notification_history_provider.dart';
import 'whatsapp_web_feed_provider.dart';
import '../../personal_agent/application/conversation_ownership_policy.dart';
import '../../../../core/providers/settings_provider.dart';
import '../../application/automation_coordinator_provider.dart';
import '../../engine/agent_dependencies.dart'
    show conversationAssignmentStoreProvider;
import 'messaging_assigned_agent.dart';

export 'messaging_live_notifications_provider.dart';
export 'whatsapp_web_feed_provider.dart';

part 'messaging_center_counts.dart';
part 'messaging_center_aggregation.part.dart';

final selectedPlatformFilterProvider = StateProvider<MessagingPlatform?>(
  (ref) => null,
);
final selectedCategoryTabProvider = StateProvider<MessagingCategoryFilter>(
  (ref) => MessagingCategoryFilter.all,
);
final messagingSearchQueryProvider = StateProvider<String>((ref) => '');

/// Estado local y reversible de archivo del hub; no muta WhatsApp.
final conversationHubArchiveStoreProvider =
    Provider<ConversationHubArchiveStore>((ref) {
      return ConversationHubArchiveStore();
    });

final archivedConversationIdsProvider = FutureProvider<Set<String>>((ref) {
  return ref.watch(conversationHubArchiveStoreProvider).load();
});

final removedConversationIdsProvider = FutureProvider<Map<String, int>>((ref) {
  return ref.watch(conversationHubArchiveStoreProvider).loadRemoved();
});

/// Estado de acceso del listener de notificaciones en Android
final notificationAccessProvider =
    FutureProvider.autoDispose<NotificationAccessStatus>((ref) async {
      final executor = ref.watch(notificationExecutorProvider);
      return executor.status();
    });

final filteredConversationsProvider =
    Provider<AsyncValue<List<ConversationSummaryItem>>>((ref) {
      final allAsync = ref.watch(allHubConversationsProvider);
      final archivedAsync = ref.watch(archivedConversationIdsProvider);
      final removedMap =
          ref.watch(removedConversationIdsProvider).valueOrNull ?? const {};
      final platform = ref.watch(selectedPlatformFilterProvider);
      final category = ref.watch(selectedCategoryTabProvider);
      final search = ref
          .watch(messagingSearchQueryProvider)
          .trim()
          .toLowerCase();

      return archivedAsync.when(
        loading: () => const AsyncLoading(),
        error: AsyncError.new,
        data: (archivedIds) => allAsync.whenData((list) {
          return list.where((item) {
            if (isMessagingConversationRemoved(item, removedMap)) {
              return false;
            }
            final isArchived = isMessagingConversationArchived(
              item,
              archivedIds,
            );
            if (category == MessagingCategoryFilter.archived) {
              if (!isArchived) return false;
            } else if (isArchived) {
              return false;
            }
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
                if (!item.hasPendingReply) {
                  return false;
                }
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
              if (!name.contains(search) && !last.contains(search)) {
                return false;
              }
            }
            return true;
          }).toList();
        }),
      );
    });
