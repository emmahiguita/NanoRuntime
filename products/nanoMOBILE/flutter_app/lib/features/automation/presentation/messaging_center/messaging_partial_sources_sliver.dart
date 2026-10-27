import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../engine/messaging/conversation_hub_providers.dart';
import 'messaging_center_providers.dart';
import 'notification_history_provider.dart';

/// Conserva los chats disponibles y explica cuando falta una fuente local.
class MessagingPartialSourcesSliver extends ConsumerWidget {
  const MessagingPartialSourcesSliver({super.key, required this.child});
  final Widget child;

  // Las escuchas pertenecen a Riverpod y desaparecen al desmontar el widget.
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(localMessagingLoadErrorProvider)) return child;
    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: MaterialBanner(
            content: const Text(
              'Carga parcial: el archivo local no está disponible. '
              'Los chats visibles se conservan.',
            ),
            actions: [
              TextButton(
                // Reintento explícito y único: no inicia un bucle periódico oculto.
                onPressed: () {
                  ref.invalidate(notificationHistoryConversationsProvider);
                  ref.invalidate(liveNotificationsProvider);
                  ref.read(conversationHubVersionProvider.notifier).state++;
                },
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
        child,
      ],
    );
  }
}
