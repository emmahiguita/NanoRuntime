import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/messaging_platform.dart';
import '../../engine/messaging/conversation_agent.dart';
import '../../engine/messaging/conversation_hub_providers.dart';
import '../../executors/notification_executor.dart';
import '../../executors/notification_executor_provider.dart';

/// Plataforma de mensajería filtrada actualmente (null = todas).
final selectedPlatformFilterProvider =
    StateProvider<MessagingPlatform?>((ref) => null);

/// Pestaña de categoría activa.
final selectedCategoryTabProvider =
    StateProvider<MessagingCategoryFilter>((ref) => MessagingCategoryFilter.all);

/// Consulta de búsqueda en tiempo real.
final messagingSearchQueryProvider = StateProvider<String>((ref) => '');

/// Agrega conversaciones de ambos agentes (personal y negocios).
final allHubConversationsProvider =
    FutureProvider<List<ConversationSummaryItem>>((ref) async {
  final personalList = await ref.watch(
    conversationHubListProvider(ConversationAgentId.personal).future,
  );
  final businessList = await ref.watch(
    conversationHubListProvider(ConversationAgentId.business).future,
  );

  final combined = <String, ConversationSummaryItem>{};
  for (final item in [...personalList, ...businessList]) {
    combined[item.conversationId] = item;
  }

  final list = combined.values.toList()
    ..sort((a, b) => b.lastAtMs.compareTo(a.lastAtMs));

  return list;
});

/// Conteo de no leídos por plataforma.
final platformUnreadCountsProvider = Provider<Map<MessagingPlatform, int>>((ref) {
  final conversationsAsync = ref.watch(allHubConversationsProvider);
  final counts = <MessagingPlatform, int>{
    for (final p in MessagingPlatform.values) p: 0,
  };

  final list = conversationsAsync.value ?? const [];
  for (final item in list) {
    final platform = MessagingPlatform.fromPackageAndAgent(item.packageName, item.agentId);
    if (item.hasPendingReply) {
      counts[platform] = (counts[platform] ?? 0) + 1;
    }
  }

  return counts;
});

/// Total global de no leídos.
final totalUnreadCountProvider = Provider<int>((ref) {
  final counts = ref.watch(platformUnreadCountsProvider);
  return counts.values.fold(0, (sum, count) => sum + count);
});

/// Lista final filtrada por búsqueda, pestaña y plataforma seleccionada.
final filteredMessagingConversationsProvider =
    Provider<List<ConversationSummaryItem>>((ref) {
  final allAsync = ref.watch(allHubConversationsProvider);
  final list = allAsync.value ?? const [];

  final selectedPlatform = ref.watch(selectedPlatformFilterProvider);
  final category = ref.watch(selectedCategoryTabProvider);
  final query = ref.watch(messagingSearchQueryProvider).trim().toLowerCase();

  return list.where((item) {
    // 1. Filtro por plataforma de app
    if (selectedPlatform != null && selectedPlatform != MessagingPlatform.other) {
      final itemPlatform =
          MessagingPlatform.fromPackageAndAgent(item.packageName, item.agentId);
      if (itemPlatform != selectedPlatform) return false;
    }

    // 2. Filtro por categoría
    switch (category) {
      case MessagingCategoryFilter.all:
        break;
      case MessagingCategoryFilter.unread:
        if (!item.hasPendingReply) return false;
        break;
      case MessagingCategoryFilter.personal:
        if (item.agentId != ConversationAgentId.personal) return false;
        break;
      case MessagingCategoryFilter.business:
        if (item.agentId != ConversationAgentId.business) return false;
        break;
      case MessagingCategoryFilter.bots:
        if (item.humanOwns) return false;
        break;
      case MessagingCategoryFilter.archived:
        return false;
      case MessagingCategoryFilter.contacts:
        return false;
    }

    // 3. Filtro por texto de búsqueda
    if (query.isNotEmpty) {
      final nameMatches = item.displayName.toLowerCase().contains(query);
      final msgMatches = item.lastMessage.toLowerCase().contains(query);
      final appMatches = item.appLabel.toLowerCase().contains(query);
      if (!nameMatches && !msgMatches && !appMatches) return false;
    }

    return true;
  }).toList();
});

/// Estado real del listener de notificaciones de Android.
/// Se refresca cada vez que se lee (autoDispose) para reflejar cambios.
final notificationAccessProvider =
    FutureProvider.autoDispose<NotificationAccessStatus>((ref) async {
  final executor = ref.watch(notificationExecutorProvider);
  return executor.status();
});

/// Notificaciones activas del sistema convertidas en ConversationSummaryItem
/// para mostrar datos reales en el hub incluso antes de que el pipeline las
/// haya procesado en la BD de memoria conversacional.
final liveNotificationsProvider =
    FutureProvider.autoDispose<List<ConversationSummaryItem>>((ref) async {
  final executor = ref.watch(notificationExecutorProvider);
  final status = await executor.status();
  if (!status.connected) return const [];

  final notifications = await executor.list(limit: 50);
  final seen = <String>{};
  final items = <ConversationSummaryItem>[];
  final now = DateTime.now().millisecondsSinceEpoch;

  // Paquetes de mensajería soportados
  const supportedPackages = {
    'com.whatsapp',
    'com.whatsapp.w4b',
    'org.telegram.messenger',
    'com.instagram.android',
    'com.facebook.orca',
    'com.slack',
    'com.google.android.gm',
    'com.twitter.android',
    'com.linkedin.android',
  };

  for (final notif in notifications) {
    if (!supportedPackages.contains(notif.packageName)) continue;

    // Clave de deduplicación por conversación
    final convKey = notif.conversationId.isNotEmpty
        ? notif.conversationId
        : '${notif.packageName}:${notif.title}';
    if (seen.contains(convKey)) continue;
    seen.add(convKey);

    final agentId = notif.packageName == 'com.whatsapp.w4b'
        ? ConversationAgentId.business
        : ConversationAgentId.personal;

    final displayName = notif.sender.isNotEmpty
        ? notif.sender
        : (notif.title.isNotEmpty ? notif.title : 'Chat');

    final messageText = notif.messageText.isNotEmpty
        ? notif.messageText
        : (notif.text.isNotEmpty ? notif.text : '');

    final atMs = notif.messageTimestamp > 0
        ? notif.messageTimestamp
        : (notif.postedAt.millisecondsSinceEpoch > 0
            ? notif.postedAt.millisecondsSinceEpoch
            : now);

    items.add(
      ConversationSummaryItem(
        conversationId: 'live:$convKey',
        displayName: displayName,
        packageName: notif.packageName,
        lastMessage: messageText,
        lastAtMs: atMs,
        hasPendingReply: notif.canReply,
        agentId: agentId,
        entryCount: 1,
        notificationKey: notif.key,
      ),
    );
  }

  items.sort((a, b) => b.lastAtMs.compareTo(a.lastAtMs));
  return items;
});
