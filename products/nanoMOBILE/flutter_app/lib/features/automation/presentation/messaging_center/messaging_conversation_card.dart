import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../domain/messaging_platform.dart';
import '../../engine/messaging/conversation_hub_providers.dart';
import 'messaging_platform_icon.dart';

/// Tarjeta de conversación hiperrealista con micro-animaciones táctiles,
/// badges de estado y diseño idéntico a la referencia visual.
class MessagingConversationCard extends StatefulWidget {
  final ConversationSummaryItem item;
  final VoidCallback onTap;
  /// Si true, la notificación está activa en Android pero aún no en la BD.
  final bool isLive;

  const MessagingConversationCard({
    super.key,
    required this.item,
    required this.onTap,
    this.isLive = false,
  });

  @override
  State<MessagingConversationCard> createState() =>
      _MessagingConversationCardState();
}

class _MessagingConversationCardState extends State<MessagingConversationCard> {
  bool _pressed = false;

  static const List<List<Color>> _avatarGradients = [
    [Color(0xFF3B82F6), Color(0xFF1D4ED8)], // Azul
    [Color(0xFF10B981), Color(0xFF047857)], // Esmeralda
    [Color(0xFF8B5CF6), Color(0xFF6D28D9)], // Violeta
    [Color(0xFFF59E0B), Color(0xFFB45309)], // Ámbar
    [Color(0xFFEC4899), Color(0xFFBE185D)], // Rosa
    [Color(0xFF06B6D4), Color(0xFF0E7490)], // Cian
  ];

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final platform = MessagingPlatform.fromPackageAndAgent(item.packageName, item.agentId);
    final timeStr = _formatTimestamp(item.lastAtMs);
    final isGroup = item.displayName.toLowerCase().contains('grupo') ||
        item.displayName.toLowerCase().contains('equipo') ||
        item.displayName.toLowerCase().contains('team');
    final isVip = item.displayName.toLowerCase().contains('emmanuel') ||
        item.displayName.toLowerCase().contains('emma');
    final isVerified = item.displayName.contains('@');

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: _pressed
                  ? [
                      const Color(0x551E293B),
                      const Color(0x400F172A),
                    ]
                  : [
                      const Color(0x381E293B),
                      const Color(0x220F172A),
                    ],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: _pressed
                  ? const Color(0xFF007AFF).withValues(alpha: 0.45)
                  : Colors.white.withValues(alpha: 0.11),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // 1. Icono oficial de la plataforma
              MessagingPlatformIcon(
                platform: platform,
                size: 38,
                borderRadius: 11,
              ),
              const SizedBox(width: 12),

              // 2. Avatar con gradiente individual o icono grupal
              _buildAvatar(item.displayName, isGroup),
              const SizedBox(width: 12),

              // 3. Contenido de texto central
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            item.displayName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14.5,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isVip) ...[
                          const SizedBox(width: 5),
                          const Icon(
                            Icons.star_rounded,
                            size: 15,
                            color: Color(0xFFFFB800),
                          ),
                        ],
                        if (isGroup) ...[
                          const SizedBox(width: 5),
                          const Icon(
                            Icons.group_rounded,
                            size: 14,
                            color: Color(0xFF60A5FA),
                          ),
                        ],
                        if (isVerified) ...[
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.verified_rounded,
                            size: 14,
                            color: Color(0xFF00A3FF),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item.lastMessage,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.65),
                        fontSize: 12.5,
                        height: 1.25,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // 4. Panel derecho (hora, pin, badge no leídos, chevron)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.isLive) ...[
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Color(0xFF00FF88),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                      ],
                      Text(
                        timeStr,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.45),
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      if (isVip) ...[
                        const SizedBox(width: 4),
                        Transform.rotate(
                          angle: 0.5,
                          child: Icon(
                            Icons.push_pin_rounded,
                            size: 12,
                            color: Colors.white.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (item.hasPendingReply || item.entryCount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00E676),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF00E676).withValues(alpha: 0.4),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                          child: Text(
                            item.hasPendingReply
                                ? '1'
                                : '${item.entryCount.clamp(1, 9)}',
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      const SizedBox(width: 6),
                      Icon(
                        CupertinoIcons.chevron_right,
                        size: 14,
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(String name, bool isGroup) {
    if (isGroup) {
      return Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.12),
            width: 1,
          ),
        ),
        child: const Center(
          child: Icon(
            Icons.groups_rounded,
            color: Color(0xFF94A3B8),
            size: 20,
          ),
        ),
      );
    }

    final gradientIndex = (name.hashCode.abs()) % _avatarGradients.length;
    final gradient = _avatarGradients[gradientIndex];
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.18),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: gradient.first.withValues(alpha: 0.25),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  String _formatTimestamp(int ms) {
    if (ms <= 0) return '';
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 1) return 'Ahora';
    if (diff.inHours < 1) return '${diff.inMinutes} m';
    if (diff.inDays < 1) {
      final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
      final period = dt.hour >= 12 ? 'p. m.' : 'a. m.';
      final min = dt.minute.toString().padLeft(2, '0');
      return '$hour:$min $period';
    }
    if (diff.inDays == 1) return 'Ayer';
    return '${dt.day}/${dt.month}';
  }
}
