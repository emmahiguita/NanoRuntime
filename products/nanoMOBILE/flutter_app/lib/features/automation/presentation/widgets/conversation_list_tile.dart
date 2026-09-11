import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:nanoai/core/widgets/interactive_glass_card.dart';
import '../../engine/messaging/conversation_hub_providers.dart';
import '../automation_visual_theme.dart';

class ConversationListTile extends StatelessWidget {
  final ConversationSummaryItem item;
  final VoidCallback onTap;
  final VoidCallback? onApprovePending;

  static const List<String> _sfFallback = [
    '.SF UI Text',
    '.SF UI Display',
    'SF Pro Text',
    'SF Pro Display',
    'Inter',
    'Roboto',
  ];

  const ConversationListTile({
    super.key,
    required this.item,
    required this.onTap,
    this.onApprovePending,
  });

  @override
  Widget build(BuildContext context) {
    final visual = AutomationVisual.of(context);
    final timeStr = _formatTimestamp(item.lastAtMs);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: GestureDetector(
        onTap: onTap,
        child: InteractiveGlassCard(
          child: Padding(
            padding: const EdgeInsets.all(14.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _buildAvatar(visual),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  item.displayName,
                                  style: TextStyle(
                                    color: visual.text,
                                    fontFamily: 'Inter',
                                    fontFamilyFallback: _sfFallback,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: -0.4,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                timeStr,
                                style: TextStyle(
                                  color: visual.textMuted,
                                  fontFamily: 'Inter',
                                  fontFamilyFallback: _sfFallback,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              _buildAppIcon(visual),
                              const SizedBox(width: 5),
                              Text(
                                item.appLabel,
                                style: TextStyle(
                                  color: visual.textMuted,
                                  fontFamily: 'Inter',
                                  fontFamilyFallback: _sfFallback,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  item.lastMessage,
                  style: TextStyle(
                    color: visual.text.withValues(alpha: 0.88),
                    fontFamily: 'Inter',
                    fontFamilyFallback: _sfFallback,
                    fontSize: 13.5,
                    height: 1.35,
                    letterSpacing: -0.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildStatusBadge(visual),
                    const Spacer(),
                    if (item.hasPendingReply && onApprovePending != null)
                      Padding(
                        padding: const EdgeInsets.only(right: 6.0),
                        child: InkWell(
                          onTap: onApprovePending,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF9500).withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFFFF9500).withValues(alpha: 0.45),
                              ),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  CupertinoIcons.checkmark_alt_circle_fill,
                                  size: 13,
                                  color: Color(0xFFFF9500),
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Aprobar Borrador',
                                  style: TextStyle(
                                    color: Color(0xFFFF9500),
                                    fontFamily: 'Inter',
                                    fontFamilyFallback: _sfFallback,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    Icon(
                      CupertinoIcons.chevron_right,
                      color: visual.textMuted.withValues(alpha: 0.7),
                      size: 16,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(AutomationVisualPalette visual) {
    final statusColor = item.humanOwns
        ? visual.accent
        : (item.hasPendingReply
            ? const Color(0xFFFF9500)
            : visual.success);

    return Stack(
      children: [
        Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                visual.accent.withValues(alpha: 0.25),
                visual.accent.withValues(alpha: 0.08),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
            border: Border.all(
              color: visual.accent.withValues(alpha: 0.35),
              width: 1.2,
            ),
          ),
          child: Text(
            item.displayName.isNotEmpty ? item.displayName[0].toUpperCase() : '?',
            style: TextStyle(
              color: visual.accent,
              fontFamily: 'Inter',
              fontFamilyFallback: _sfFallback,
              fontWeight: FontWeight.w700,
              fontSize: 17,
            ),
          ),
        ),
        Positioned(
          right: 0,
          bottom: 0,
          child: Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
              border: Border.all(
                color: visual.canvas,
                width: 2,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAppIcon(AutomationVisualPalette visual) {
    if (item.packageName.contains('w4b')) {
      return Image.asset(
        'assets/automation/whatsapp_business_icon.png',
        width: 14,
        height: 14,
        errorBuilder: (_, __, ___) => Icon(
          CupertinoIcons.building_2_fill,
          size: 14,
          color: visual.success,
        ),
      );
    }
    return Image.asset(
      'assets/automation/whatsapp_icon.png',
      width: 14,
      height: 14,
      errorBuilder: (_, __, ___) => Icon(
        CupertinoIcons.chat_bubble_2_fill,
        size: 14,
        color: visual.success,
      ),
    );
  }

  Widget _buildStatusBadge(AutomationVisualPalette visual) {
    if (item.humanOwns) {
      return _badge(
        label: 'Control Humano',
        color: visual.accent,
        icon: CupertinoIcons.person_fill,
      );
    }
    if (item.hasPendingReply) {
      return _badge(
        label: 'Borrador Pendiente',
        color: const Color(0xFFFF9500),
        icon: CupertinoIcons.timer,
      );
    }
    return _badge(
      label: 'IA Activa',
      color: visual.success,
      icon: CupertinoIcons.sparkles,
    );
  }

  Widget _badge({
    required String label,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontFamily: 'Inter',
              fontFamilyFallback: _sfFallback,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(int ms) {
    if (ms <= 0) return '';
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Ahora';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }
}
