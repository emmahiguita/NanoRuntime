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

/// Estado de acceso del listener de notificaciones en Android
final notificationAccessProvider =
    FutureProvider.autoDispose<NotificationAccessStatus>((ref) async {
      final executor = ref.watch(notificationExecutorProvider);
      return executor.status();
    });

/// Carga las fuentes locales. WhatsApp Web queda fuera para que cada cambio
/// del DOM no vuelva a consultar SQLite, notificaciones y asignaciones.
final _localHubConversationsProvider =
    FutureProvider<List<ConversationSummaryItem>>((ref) async {
      // Las cuatro fuentes son independientes. Esperarlas en serie hacía que
      // cada refresco Web/notificación sumara todas sus latencias y ocultara
      // la lista completa detrás de un spinner.
      final sources = await Future.wait<List<ConversationSummaryItem>>([
        ref.watch(
          conversationHubListProvider(ConversationAgentId.personal).future,
        ),
        ref.watch(
          conversationHubListProvider(ConversationAgentId.business).future,
        ),
        ref.watch(liveNotificationsProvider.future),
        ref.watch(notificationHistoryConversationsProvider.future),
      ]);
      final personalList = sources[0];
      final businessList = sources[1];
      final liveList = sources[2];
      final notificationHistory = sources[3];
      final ownership = ref.watch(conversationOwnershipStoreProvider);
      final targetMode = ref.watch(settingsProvider).waTargetContactsMode;
      final assignments = ref.watch(conversationAssignmentStoreProvider);
      await Future.wait<void>([ownership.load(), assignments.load()]);

      final merged = MessagingDedupMerger.deduplicateAndSort([
        ...personalList,
        ...businessList,
        ...notificationHistory,
        ...liveList,
      ]);
      // Ser un historial solo de lectura no equivale a una pausa del agente.
      // Lista, menú y detalle consultan la misma autorización persistida.
      return [
        for (final item in merged)
          item.withHumanOwnership(
            ConversationOwnershipPolicy.humanOwns(
              targetContactsMode: targetMode,
              ownership: ConversationOwnershipPolicy.ownershipForConversation(
                store: ownership,
                conversationId: item.conversationId,
                packageName: item.packageName,
                isGroup: item.isGroup,
                aliases: item.conversationAliases,
              ),
            ),
            assignedAgent: messagingAssignedAgent(item, assignments),
          ),
      ];
    });

/// Une el snapshot Web en memoria con la carga local ya hidratada. Así el
/// panel puede reflejar Web inmediatamente sin multiplicar lecturas lentas.
final allHubConversationsProvider =
    FutureProvider<List<ConversationSummaryItem>>((ref) async {
      final local = await ref.watch(_localHubConversationsProvider.future);
      final whatsappWebList = ref.watch(whatsappWebConversationItemsProvider);
      return MessagingDedupMerger.deduplicateAndSort([
        ...local,
        ...whatsappWebList,
      ]);
    });

final filteredConversationsProvider =
    Provider<AsyncValue<List<ConversationSummaryItem>>>((ref) {
      final allAsync = ref.watch(allHubConversationsProvider);
      final archivedAsync = ref.watch(archivedConversationIdsProvider);
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
