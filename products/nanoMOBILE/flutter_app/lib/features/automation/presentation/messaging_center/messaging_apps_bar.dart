import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/messaging_platform.dart';
import 'messaging_center_providers.dart';
import 'messaging_platform_icon.dart';

/// Barra horizontal de apps conectadas con badges de no leídos y selección activa.
class MessagingAppsBar extends ConsumerWidget {
  const MessagingAppsBar({super.key});

  static const _displayedPlatforms = [
    MessagingPlatform.whatsapp,
    MessagingPlatform.whatsappBusiness,
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

    return SizedBox(
      height: 64,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: _displayedPlatforms.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final platform = _displayedPlatforms[index];
          final isSelected = selected == platform;
          final unread = unreadCounts[platform] ?? 0;
          final isMore = platform == MessagingPlatform.other;

          final compactLabel = switch (platform) {
            MessagingPlatform.whatsapp => 'Personal',
            MessagingPlatform.whatsappBusiness => 'Negocio',
            MessagingPlatform.other => 'Más',
            _ => platform.label,
          };

          return _AppTile(
            platform: platform,
            label: isMore ? 'Más' : compactLabel,
            isSelected: isSelected,
            unreadCount: unread,
            onTap: () {
              if (isSelected) {
                // Deseleccionar para volver a ver todas
                ref.read(selectedPlatformFilterProvider.notifier).state = null;
              } else {
                ref.read(selectedPlatformFilterProvider.notifier).state = platform;
              }
            },
          );
        },
      ),
    );
  }
}

class _AppTile extends StatelessWidget {
  final MessagingPlatform platform;
  final String label;
  final bool isSelected;
  final int unreadCount;
  final VoidCallback onTap;

  const _AppTile({
    required this.platform,
    required this.label,
    required this.isSelected,
    required this.unreadCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 58,
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF00FF88).withValues(alpha: 0.12)
              : const Color(0xFF0F172A).withValues(alpha: 0.70),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF00FF88)
                : Colors.white.withValues(alpha: 0.08),
            width: isSelected ? 1.5 : 0.9,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF00FF88).withValues(alpha: 0.30),
                    blurRadius: 10,
                    spreadRadius: 0.5,
                  ),
                ]
              : null,
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  MessagingPlatformIcon(platform: platform, size: 26, borderRadius: 8),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    style: TextStyle(
                      color: isSelected
                          ? const Color(0xFF00FF88)
                          : Colors.white.withValues(alpha: 0.85),
                      fontSize: 10,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      letterSpacing: -0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (unreadCount > 0)
              Positioned(
                top: 2,
                right: 2,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00FF88),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00FF88).withValues(alpha: 0.4),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      unreadCount > 99 ? '99+' : '$unreadCount',
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 8.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
