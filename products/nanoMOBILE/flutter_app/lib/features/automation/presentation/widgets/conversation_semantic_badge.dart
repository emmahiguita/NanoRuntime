import 'package:flutter/material.dart';

import '../../engine/language/conversation_semantic_tag.dart';

class ConversationSemanticBadge extends StatelessWidget {
  const ConversationSemanticBadge({
    super.key,
    required this.tag,
    this.compact = false,
  });

  final ConversationSemanticTag tag;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = _color(tag);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 5 : 6,
        vertical: compact ? 2 : 2.5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.28), width: 0.7),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_icon(tag), size: compact ? 9 : 10, color: color),
          const SizedBox(width: 3),
          Text(
            tag.label.toUpperCase(),
            style: TextStyle(
              color: color,
              fontSize: compact ? 7.5 : 8.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.35,
            ),
          ),
        ],
      ),
    );
  }

  static IconData _icon(ConversationSemanticTag tag) => switch (tag) {
    ConversationSemanticTag.greeting => Icons.waving_hand_outlined,
    ConversationSemanticTag.farewell => Icons.logout_rounded,
    ConversationSemanticTag.gratitude => Icons.favorite_border_rounded,
    ConversationSemanticTag.question => Icons.help_outline_rounded,
    ConversationSemanticTag.request => Icons.task_alt_rounded,
    ConversationSemanticTag.correction => Icons.edit_note_rounded,
    ConversationSemanticTag.profile => Icons.person_outline_rounded,
    ConversationSemanticTag.media => Icons.perm_media_outlined,
    ConversationSemanticTag.conversation => Icons.forum_outlined,
  };

  static Color _color(ConversationSemanticTag tag) => switch (tag) {
    ConversationSemanticTag.greeting => const Color(0xFF34D399),
    ConversationSemanticTag.farewell => const Color(0xFFA78BFA),
    ConversationSemanticTag.gratitude => const Color(0xFFF472B6),
    ConversationSemanticTag.question => const Color(0xFF60A5FA),
    ConversationSemanticTag.request => const Color(0xFFFBBF24),
    ConversationSemanticTag.correction => const Color(0xFFFB7185),
    ConversationSemanticTag.profile => const Color(0xFF22D3EE),
    ConversationSemanticTag.media => const Color(0xFFC084FC),
    ConversationSemanticTag.conversation => const Color(0xFF94A3B8),
  };
}
