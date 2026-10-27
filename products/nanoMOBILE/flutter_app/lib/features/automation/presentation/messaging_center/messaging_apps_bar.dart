// messaging_apps_bar.dart
//
// QUÉ HACE:
// Filtros Material de WhatsApp Personal y Negocio con altura adaptable.
//
// CÓMO FUNCIONA:
// - Despliega únicamente WhatsApp Personal y WhatsApp Negocio.
// - Orquesta el estado reactivo con Riverpod (selectedPlatformFilterProvider).
//
// POR QUÉ:
// Evita nombres idénticos truncados y adapta los controles a texto grande.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/messaging_platform.dart';
import 'messaging_platform_icon.dart';
import 'messaging_center_providers.dart';

class MessagingAppsBar extends ConsumerWidget {
  const MessagingAppsBar({super.key});

  static const _displayedPlatforms = [
    MessagingPlatform.whatsapp,
    MessagingPlatform.whatsappBusiness,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedPlatformFilterProvider);
    final unreadCounts = ref.watch(platformUnreadCountsProvider);

    // Wrap conserva blancos táctiles y pasa a otra fila si el texto crece.
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _displayedPlatforms
          .map((platform) {
            final isSelected = selected == platform;
            final unread = unreadCounts[platform] ?? 0;
            final compactLabel = switch (platform) {
              MessagingPlatform.whatsapp => 'Personal',
              MessagingPlatform.whatsappBusiness => 'Negocio',
              _ => platform.label,
            };

            return FilterChip(
              avatar: MessagingPlatformIcon(
                platform: platform,
                size: 24,
                borderRadius: 6,
              ),
              label: Text(
                unread > 0 ? '$compactLabel ($unread)' : compactLabel,
              ),
              selected: isSelected,
              showCheckmark: false,
              onSelected: (_) {
                ref.read(selectedPlatformFilterProvider.notifier).state =
                    isSelected ? null : platform;
              },
            );
          })
          .toList(growable: false),
    );
  }
}
