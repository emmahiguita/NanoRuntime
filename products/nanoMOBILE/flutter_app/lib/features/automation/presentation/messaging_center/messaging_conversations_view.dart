/// MESSAGING-CONVERSATIONS-VIEW — Lista interactiva de conversaciones activas y archivadas.
///
/// **QUÉ HACE:**
/// Renderiza las tarjetas de conversación unificadas con indicador en vivo,
/// filtrado por pestaña/búsqueda y enlace al visor de detalle.
///
/// **CÓMO FUNCIONA:**
/// Observa [filteredMessagingConversationsProvider], [allHubConversationsProvider] y
/// [liveNotificationsProvider]. Si no hay mensajes, delega en [MessagingEmptyState].
///
/// **POR QUÉ:**
/// Separa la presentación de la lista de conversaciones para mantener el código
/// limpio, mantenible y bajo el límite estricto de 200 líneas (Clean Architecture).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../engine/messaging/conversation_hub_providers.dart';
import '../widgets/conversation_detail_sheet.dart';
import 'messaging_center_banners.dart';
import 'messaging_center_providers.dart';
import 'messaging_error_card.dart';
import 'notification_history_provider.dart'
    show notificationHistoryConversationsProvider;
import 'messaging_conversation_card.dart';
import 'messaging_conversation_actions_sheet.dart';
import 'messaging_conversation_keys.dart';

class MessagingConversationsView extends ConsumerWidget {
  const MessagingConversationsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filteredAsync = ref.watch(filteredConversationsProvider);
    final allHubAsync = ref.watch(allHubConversationsProvider);
    final liveAsync = ref.watch(liveNotificationsProvider);
    final archivedIds =
        ref.watch(archivedConversationIdsProvider).value ?? const {};
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = NanoThemeExtension.of(context).colors;
    final accentColor = isDark ? const Color(0xFF00FF88) : colors.primary;

    // 1. Carga inicial
    if ((allHubAsync.isLoading && liveAsync.isLoading) ||
        filteredAsync.isLoading) {
      return SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: CircularProgressIndicator(color: accentColor),
          ),
        ),
      );
    }

    // 2. Error en ambas fuentes
    if (allHubAsync.hasError && liveAsync.hasError) {
      return SliverToBoxAdapter(
        child: MessagingErrorCard(
          error: allHubAsync.error.toString(),
          onRetry: () {
            ref.invalidate(notificationHistoryConversationsProvider);
            ref.invalidate(allHubConversationsProvider);
            ref.invalidate(liveNotificationsProvider);
            ref.read(conversationHubVersionProvider.notifier).state++;
          },
        ),
      );
    }

    // El archivo durable falla de forma visible; no se oculta como lista vacía.
    if (filteredAsync.hasError) {
      return SliverToBoxAdapter(
        child: MessagingErrorCard(
          error: filteredAsync.error.toString(),
          onRetry: () {
            ref.invalidate(archivedConversationIdsProvider);
            ref.invalidate(notificationHistoryConversationsProvider);
            ref.invalidate(allHubConversationsProvider);
            ref.invalidate(liveNotificationsProvider);
            ref.read(conversationHubVersionProvider.notifier).state++;
          },
        ),
      );
    }

    // Presenta exactamente el resultado filtrado por búsqueda y categoría.
    final itemsToShow =
        filteredAsync.value ?? const <ConversationSummaryItem>[];
    // Una búsqueda o pestaña sin coincidencias debe permanecer vacía. El
    // fallback anterior volvía a mostrar todos los chats y hacía que la
    // pestaña "Grupos" incluyera conversaciones directas.
    if (itemsToShow.isEmpty) {
      return const SliverToBoxAdapter(child: MessagingEmptyState());
    }

    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    // Comparte la misma lógica de tarjeta para lista vertical y cuadrícula horizontal.
    Widget cardAt(BuildContext itemContext, int index) {
      final item = itemsToShow[index];
      final isLive = item.notificationKey?.trim().isNotEmpty == true;
      final isArchived = isMessagingConversationArchived(item, archivedIds);
      return MessagingConversationCard(
        item: item,
        isLive: isLive,
        onTap: () => ConversationDetailSheet.show(itemContext, item),
        onMore: () => showMessagingConversationActions(
          itemContext,
          ref,
          item,
          isArchived: isArchived,
          currentAgent: item.agentId,
        ),
      );
    }

    return isLandscape
        ? SliverGrid.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisExtent: 88,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: itemsToShow.length,
            itemBuilder: cardAt,
          )
        : SliverList.builder(
            itemCount: itemsToShow.length,
            itemBuilder: cardAt,
          );
  }
}
