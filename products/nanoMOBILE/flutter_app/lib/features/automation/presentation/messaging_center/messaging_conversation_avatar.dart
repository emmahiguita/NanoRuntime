import 'package:flutter/material.dart';

import '../../domain/messaging_platform.dart';
import '../../engine/messaging/conversation_hub_providers.dart';
import 'messaging_platform_icon.dart';

/// Avatar estilizado estilo iOS con paleta armónica de colores pastel/vibrantes
/// y badge de plataforma flotante con aro protector.
class MessagingConversationAvatar extends StatelessWidget {
  const MessagingConversationAvatar({
    super.key,
    required this.item,
    required this.platform,
    this.size = 48,
  });

  final ConversationSummaryItem item;
  final MessagingPlatform platform;
  final double size;

  static const _palette = [
    Color(0xFF0D9488), // Teal
    Color(0xFFE11D48), // Rose
    Color(0xFF7C3AED), // Violet
    Color(0xFF0284C7), // Sky Blue
    Color(0xFFD97706), // Amber
    Color(0xFF059669), // Emerald
    Color(0xFF4F46E5), // Indigo
    Color(0xFF334155), // Slate
  ];

  Color _avatarColor(String name) {
    if (name.isEmpty) return const Color(0xFF64748B);
    final hash = name.codeUnits.fold(0, (prev, elem) => prev + elem);
    return _palette[hash.abs() % _palette.length];
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final badgeBg = isDark ? const Color(0xFF0F172A) : Colors.white;
    final cleanName = item.displayName.trim();
    final initial = cleanName.isEmpty
        ? '?'
        : cleanName.characters.first.toUpperCase();
    final avatarBg = item.isGroup
        ? (isDark ? const Color(0xFF1E3A8A) : const Color(0xFF3B82F6))
        : _avatarColor(cleanName);

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: avatarBg,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: avatarBg.withValues(alpha: isDark ? 0.35 : 0.25),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: item.isGroup
                  ? Icon(
                      Icons.groups_rounded,
                      size: size * 0.48,
                      color: Colors.white,
                    )
                  : Text(
                      initial,
                      style: TextStyle(
                        fontSize: size * 0.42,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
            ),
          ),
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              padding: const EdgeInsets.all(1.5),
              decoration: BoxDecoration(
                color: badgeBg,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.1),
                    blurRadius: 3,
                  ),
                ],
              ),
              child: MessagingPlatformIcon(
                platform: platform,
                size: size * 0.38,
                borderRadius: (size * 0.38) / 2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
