import 'package:flutter/material.dart';
import '../../domain/messaging_platform.dart';
import '../../engine/messaging/conversation_hub_providers.dart';
import 'messaging_conversation_avatar.dart';
import 'messaging_conversation_time.dart';

/// Tarjeta de conversación con estilo iOS Glassed,
/// tipografía nítida, avatar con plataforma flotante y acciones discretas.
class MessagingConversationCard extends StatelessWidget {
  const MessagingConversationCard({
    super.key,
    required this.item,
    required this.onTap,
    this.onMore,
    this.isLive = false,
  });

  final ConversationSummaryItem item;
  final VoidCallback onTap;
  final VoidCallback? onMore;
  final bool isLive;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final platform = MessagingPlatform.fromPackageAndAgent(
      item.packageName,
      item.agentId,
    );

    final subtitle = item.isGroup && item.lastSender?.isNotEmpty == true
        ? '${item.lastSender}: ${item.lastMessage}'
        : item.lastMessage;

    final hasLink =
        item.lastMessage.contains('http://') ||
        item.lastMessage.contains('https://') ||
        item.lastMessage.contains('www.');

    final isUnreadOrActive = isLive || item.hasPendingReply;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.07)
                    : const Color(0xFFDDE4EC).withValues(alpha: 0.78),
                width: 0.7,
              ),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(16, 9, 14, 9),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 1. Avatar iOS estilizado compacto
              MessagingConversationAvatar(
                item: item,
                platform: platform,
                size: 42,
              ),
              const SizedBox(width: 10),

              // 2. Título y último mensaje continuo
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            item.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF0F172A),
                              fontWeight: FontWeight.w700,
                              fontSize: 14.5,
                              letterSpacing: -0.25,
                            ),
                          ),
                        ),
                        if (item.isGroup) ...[
                          const SizedBox(width: 3.5),
                          Icon(
                            Icons.groups_rounded,
                            size: 14,
                            color: isDark
                                ? Colors.white54
                                : const Color(0xFF64748B),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        if (hasLink) ...[
                          Icon(
                            Icons.link_rounded,
                            size: 12,
                            color: isDark
                                ? const Color(0xFF38BDF8)
                                : const Color(0xFF0284C7),
                          ),
                          const SizedBox(width: 3),
                        ],
                        Expanded(
                          child: Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.55)
                                  : const Color(0xFF64748B),
                              fontSize: 12.5,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // 3. Hora, indicador verde y botón de opciones (...)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isUnreadOrActive) ...[
                        Container(
                          width: 5.5,
                          height: 5.5,
                          decoration: const BoxDecoration(
                            color: Color(0xFF10B981),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                      ],
                      Text(
                        formatMessagingTimestamp(item.lastAtMs),
                        style: TextStyle(
                          color: isDark
                              ? Colors.white54
                              : const Color(0xFF94A3B8),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Semantics(
                    label: 'Opciones de conversación',
                    button: true,
                    child: InkWell(
                      onTap: onMore,
                      borderRadius: BorderRadius.circular(10),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 2,
                        ),
                        child: Icon(
                          Icons.more_horiz_rounded,
                          size: 18,
                          color: isDark
                              ? Colors.white38
                              : const Color(0xFF94A3B8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
