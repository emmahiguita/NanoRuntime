// QUÉ HACE: calcula contadores coherentes del hub.
// CÓMO: excluye archivados de pestañas activas y los cuenta por separado.
// POR QUÉ: un chat archivado no debe reaparecer como activo por un badge.

part of 'messaging_center_providers.dart';

List<ConversationSummaryItem> _activeHubItems(Ref ref) {
  final all = ref.watch(allHubConversationsProvider).value ?? const [];
  final archived = ref.watch(archivedConversationIdsProvider).value ?? const {};
  return all
      .where((item) => !isMessagingConversationArchived(item, archived))
      .toList(growable: false);
}

final platformCountsProvider = Provider<Map<MessagingPlatform, int>>((ref) {
  final active = _activeHubItems(ref);
  return {
    for (final platform in MessagingPlatform.values)
      platform: active
          .where(
            (item) =>
                MessagingPlatform.fromPackageName(item.packageName) == platform,
          )
          .length,
  };
});

final platformUnreadCountsProvider = Provider<Map<MessagingPlatform, int>>((
  ref,
) {
  final active = _activeHubItems(ref);
  return {
    for (final platform in MessagingPlatform.values)
      platform: active
          .where(
            (item) =>
                MessagingPlatform.fromPackageName(item.packageName) ==
                    platform &&
                item.hasPendingReply,
          )
          .length,
  };
});

final pendingRepliesCountProvider = Provider<int>((ref) {
  return _activeHubItems(ref).where((item) => item.hasPendingReply).length;
});

final categoryCountsProvider = Provider<Map<MessagingCategoryFilter, int>>((
  ref,
) {
  final all = ref.watch(allHubConversationsProvider).value ?? const [];
  final active = _activeHubItems(ref);
  return {
    MessagingCategoryFilter.all: active.length,
    MessagingCategoryFilter.groups: active.where((item) => item.isGroup).length,
    MessagingCategoryFilter.contacts: 0,
    MessagingCategoryFilter.unread: active
        .where((item) => item.hasPendingReply)
        .length,
    MessagingCategoryFilter.personal: active
        .where((item) => item.agentId == ConversationAgentId.personal)
        .length,
    MessagingCategoryFilter.business: active
        .where((item) => item.agentId == ConversationAgentId.business)
        .length,
    MessagingCategoryFilter.bots: active
        .where((item) => !item.humanOwns)
        .length,
    MessagingCategoryFilter.archived: all.length - active.length,
  };
});
