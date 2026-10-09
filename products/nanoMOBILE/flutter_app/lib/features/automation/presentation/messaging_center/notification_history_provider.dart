import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/nano_runtime_api.dart';
import '../../application/notification_history_client.dart';
import '../../engine/messaging/conversation_agent.dart';
import '../../engine/messaging/conversation_group_resolver.dart';
import '../../engine/messaging/conversation_hub_providers.dart'
    show ConversationSummaryItem;

/// Une SQLite local con el modelo visual usado por las conversaciones activas.
final notificationHistoryClientProvider = Provider<NotificationHistoryClient>(
  (ref) => NotificationHistoryClient(),
);

/// Reconsulta SQLite únicamente cuando Android confirma un mensaje persistido.
final notificationHistoryEventsProvider = StreamProvider.autoDispose<int>((
  ref,
) {
  return NanoRuntimeApi.instance.notificationHistoryEvents;
});

/// Convierte solo filas reales capturadas por Android; no crea chats de ejemplo.
final notificationHistoryConversationsProvider =
    FutureProvider.autoDispose<List<ConversationSummaryItem>>((ref) async {
      ref.watch(notificationHistoryEventsProvider);
      final rows = await ref
          .watch(notificationHistoryClientProvider)
          .conversations();
      return rows
          .where((row) {
            final convId = '${row['conversationId'] ?? ''}'
                .trim()
                .toLowerCase();
            final name = '${row['displayName'] ?? ''}'.trim().toLowerCase();
            final lastMsg = '${row['lastMessage'] ?? ''}'.trim().toLowerCase();
            if (convId == '0' || name == '0' || name.isEmpty) return false;
            if (convId.contains('status@broadcast') ||
                convId.contains('@newsletter')) {
              return false;
            }
            if (name == 'actualizaciones de estado' ||
                name == 'status updates' ||
                name == 'comprobando si hay mensajes...' ||
                name == 'buscando mensajes nuevos') {
              return false;
            }
            if (lastMsg.contains('le gustó tu estado') ||
                lastMsg.contains('dio me gusta a tu estado') ||
                lastMsg.contains('reacted to your status') ||
                lastMsg.contains('comprobando si hay') ||
                lastMsg.contains('buscando mensajes nuevos')) {
              return false;
            }
            return true;
          })
          .map(_summaryFromStoredNotification)
          .toList(growable: false);
    });

/// Mantiene identidad estable y marca los chats observados como bajo control humano.
ConversationSummaryItem _summaryFromStoredNotification(
  Map<String, dynamic> row,
) {
  final historyId = '${row['historyId'] ?? ''}'.trim();
  final packageName = '${row['packageName'] ?? ''}'.trim();
  final isBusiness = packageName == 'com.whatsapp.w4b';
  final rawName = '${row['displayName'] ?? ''}'.trim();
  final cleanName = ConversationGroupResolver.cleanTitle(rawName);
  final convId = '${row['conversationId'] ?? ''}'.trim();
  final name = ConversationGroupResolver.isGenericTitle(cleanName)
      ? (convId.isNotEmpty && !ConversationGroupResolver.isGenericTitle(convId)
            ? convId
            : 'Conversación')
      : cleanName;
  return ConversationSummaryItem(
    conversationId: 'history:$historyId',
    conversationAliases: ['notification-history:$historyId'],
    displayName: name,
    packageName: packageName,
    lastMessage: '${row['lastMessage'] ?? ''}',
    lastAtMs: (row['lastAtMs'] as num?)?.toInt() ?? 0,
    humanOwns: true,
    agentId: isBusiness
        ? ConversationAgentId.business
        : ConversationAgentId.personal,
    activeRole: 'historial local',
    entryCount: (row['entryCount'] as num?)?.toInt() ?? 0,
    notificationKey: '${row['notificationKey'] ?? ''}',
    isGroup: row['isGroup'] == true,
    groupTitle: row['isGroup'] == true ? name : null,
    lastSender: '${row['lastSender'] ?? ''}'.trim(),
  );
}
