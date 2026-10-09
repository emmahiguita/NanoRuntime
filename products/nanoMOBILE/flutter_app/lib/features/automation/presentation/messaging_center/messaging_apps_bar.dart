// messaging_apps_bar.dart
//
// QUÉ HACE:
// Barra horizontal de aplicaciones conectadas con diseño iOS Liquid Glass y borde metálico reflectante.
//
// CÓMO FUNCIONA:
// - Despliega selector horizontal con soporte para 'Todos', WhatsApp, Telegram, Gmail, Slack, Instagram, etc.
// - Orquesta el estado reactivo con Riverpod (selectedPlatformFilterProvider).
//
// POR QUÉ:
// Aplica SOLID modularizando las tarjetas en MessagingAppTile y manteniendo la barra bajo 90 líneas.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/messaging_platform.dart';
import 'messaging_app_tile.dart';
import 'messaging_center_providers.dart';

class MessagingAppsBar extends ConsumerWidget {
  const MessagingAppsBar({super.key});

  static const _displayedPlatforms = [
    MessagingPlatform.whatsapp,
    MessagingPlatform.telegram,
    MessagingPlatform.gmail,
    MessagingPlatform.slack,
    MessagingPlatform.instagram,
    MessagingPlatform.facebook,
    MessagingPlatform.x,
    MessagingPlatform.linkedin,
    MessagingPlatform.other,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedPlatformFilterProvider);
    final unreadCounts = ref.watch(platformUnreadCountsProvider);
    final totalUnread = ref.watch(pendingRepliesCountProvider);

    return SizedBox(
      height: 60,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: _displayedPlatforms.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 7),
        itemBuilder: (context, index) {
          if (index == 0) {
            return MessagingAppTile(
              label: 'Todos',
              isSelected: selected == null,
              unreadCount: totalUnread,
              onTap: () => ref.read(selectedPlatformFilterProvider.notifier).state = null,
            );
          }

          final platform = _displayedPlatforms[index - 1];
          final isSelected = selected == platform;
          final unread = unreadCounts[platform] ?? 0;
          final isMore = platform == MessagingPlatform.other;

          final compactLabel = switch (platform) {
            MessagingPlatform.whatsapp => 'WhatsApp',
            MessagingPlatform.whatsappBusiness => 'Negocio',
            MessagingPlatform.other => 'Más',
            _ => platform.label,
          };

          return MessagingAppTile(
            platform: platform,
            label: isMore ? 'Más' : compactLabel,
            isSelected: isSelected,
            unreadCount: unread,
            onTap: () {
              ref.read(selectedPlatformFilterProvider.notifier).state = isSelected ? null : platform;
            },
          );
        },
      ),
    );
  }
}
