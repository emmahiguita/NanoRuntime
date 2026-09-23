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
import 'messaging_conversation_card.dart';

class MessagingConversationsView extends ConsumerWidget {
  const MessagingConversationsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filteredAsync = ref.watch(filteredConversationsProvider);
    final allHubAsync = ref.watch(allHubConversationsProvider);
    final liveAsync = ref.watch(liveNotificationsProvider);

    // 1. Carga inicial
    if (allHubAsync.isLoading && liveAsync.isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(color: Color(0xFF00FF88)),
        ),
      );
    }

    // 2. Error en ambas fuentes
    if (allHubAsync.hasError && liveAsync.hasError) {
      return MessagingErrorCard(
        error: allHubAsync.error.toString(),
        onRetry: () {
          ref.invalidate(allHubConversationsProvider);
          ref.invalidate(liveNotificationsProvider);
        },
      );
    }

    final hubItems = allHubAsync.value ?? const [];
    final liveItems = liveAsync.value ?? const [];

    // 3. Fuente unificada deduplicada
    final filteredList = filteredAsync.value ?? const [];
    // Una búsqueda o pestaña sin coincidencias debe permanecer vacía. El
    // fallback anterior volvía a mostrar todos los chats y hacía que la
    // pestaña "Grupos" incluyera conversaciones directas.
    final List<ConversationSummaryItem> itemsToShow = filteredList;

    if (itemsToShow.isEmpty) {
      return const MessagingEmptyState();
    }

    final bool showLiveBadge = liveItems.isNotEmpty && filteredList.isEmpty;
    final liveIds = liveItems.map((l) => l.conversationId).toSet();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showLiveBadge && hubItems.isEmpty) ...[
          MessagingSectionLabel(
            icon: Icons.circle,
            iconColor: const Color(0xFF00FF88),
            label: 'Activas ahora',
            count: itemsToShow.length,
          ),
          const SizedBox(height: NanoSpacing.xs),
        ],
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: itemsToShow.length,
          itemBuilder: (context, index) {
            final item = itemsToShow[index];
            final isLive = liveIds.contains(item.conversationId);
            return MessagingConversationCard(
              item: item,
              isLive: isLive,
              onTap: () => ConversationDetailSheet.show(context, item),
            );
          },
        ),
      ],
    );
  }
}
