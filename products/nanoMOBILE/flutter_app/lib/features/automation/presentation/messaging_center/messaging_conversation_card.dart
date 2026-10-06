/// Tarjeta Material 3 compacta para una conversación observada.
///
/// Solo muestra estados respaldados por datos: grupo, notificación activa y
/// respuesta pendiente. No infiere VIP, verificación ni no leídos por nombre.
library;

import 'package:flutter/material.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../domain/messaging_platform.dart';
import '../../engine/language/conversation_semantic_tag.dart';
import '../../engine/messaging/conversation_hub_providers.dart';
import '../widgets/conversation_semantic_badge.dart';
import 'messaging_conversation_avatar.dart';
import 'messaging_conversation_time.dart';

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
    final colors = NanoThemeExtension.of(context).colors;
    final accentGreen = isDark ? const Color(0xFF00E676) : colors.primary;

    final platform = MessagingPlatform.fromPackageAndAgent(
      item.packageName,
      item.agentId,
    );
    final subtitle = item.isGroup && item.lastSender?.isNotEmpty == true
        ? '${item.lastSender}: ${item.lastMessage}'
        : item.lastMessage;
    final semantic = ConversationSemanticClassifier.classify(item.lastMessage);

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      color: isDark ? const Color(0xD1111928) : Colors.white,
      elevation: isDark ? 0 : 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isDark ? Colors.white.withValues(alpha: 0.09) : colors.outline,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
          child: Row(
            children: [
              MessagingConversationAvatar(item: item, platform: platform),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            item.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(
                                  color: isDark
                                      ? Colors.white
                                      : colors.onSurface,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13.5,
                                ),
                          ),
                        ),
                        if (item.isGroup) ...[
                          const SizedBox(width: 5),
                          Icon(
                            Icons.groups_rounded,
                            size: 14,
                            color: isDark
                                ? const Color(0xFF93C5FD)
                                : const Color(0xFF2563EB),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        ConversationSemanticBadge(tag: semantic, compact: true),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.58)
                                      : colors.onSurfaceVariant,
                                  fontSize: 11.5,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              SizedBox(
                width: 62,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (isLive) ...[
                          Icon(
                            Icons.circle,
                            size: 7,
                            color: accentGreen,
                          ),
                          const SizedBox(width: 4),
                        ],
                        Flexible(
                          child: Text(
                            formatMessagingTimestamp(item.lastAtMs),
                            maxLines: 1,
                            overflow: TextOverflow.fade,
                            softWrap: false,
                            style: TextStyle(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.48)
                                  : colors.onSurfaceVariant,
                              fontSize: 9.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (item.hasPendingReply)
                          Badge(
                            backgroundColor: accentGreen,
                            textColor: isDark ? Colors.black : Colors.white,
                            label: const Text('1'),
                          ),
                        // QUÉ HACE: Botón de opciones de conversación sin Tooltip intrusivo.
                        // CÓMO: Usa Semantics en lugar de tooltip: para evitar el error "No Overlay widget found".
                        // POR QUÉ: Tooltip intenta buscar Overlay.of() y crashea con cajas rojas en listas personalizadas.
                        Semantics(
                          label: 'Acciones de conversación',
                          button: true,
                          child: IconButton(
                            onPressed: onMore,
                            visualDensity: VisualDensity.compact,
                            constraints: const BoxConstraints.tightFor(
                              width: 32,
                              height: 32,
                            ),
                            padding: EdgeInsets.zero,
                            icon: Icon(
                              Icons.more_horiz_rounded,
                              size: 19,
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.62)
                                  : colors.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
