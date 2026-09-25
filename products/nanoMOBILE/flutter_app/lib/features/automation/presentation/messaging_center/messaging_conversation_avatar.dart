import 'package:flutter/material.dart';

import '../../domain/messaging_platform.dart';
import '../../engine/messaging/conversation_hub_providers.dart';
import 'messaging_platform_icon.dart';

class MessagingConversationAvatar extends StatelessWidget {
  const MessagingConversationAvatar({
    super.key,
    required this.item,
    required this.platform,
  });

  final ConversationSummaryItem item;
  final MessagingPlatform platform;

  @override
  Widget build(BuildContext context) {
    final cleanName = item.displayName.trim();
    final initial = cleanName.isEmpty
        ? '?'
        : cleanName.characters.first.toUpperCase();
    return SizedBox(
      width: 44,
      height: 44,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: item.isGroup
                ? const Color(0xFF2563EB)
                : const Color(0xFF0F766E),
            foregroundColor: Colors.white,
            child: item.isGroup
                ? const Icon(Icons.groups_rounded, size: 19)
                : Text(
                    initial,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFF0B1220),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFF0B1220), width: 2),
              ),
              child: MessagingPlatformIcon(
                platform: platform,
                size: 16,
                borderRadius: 4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
