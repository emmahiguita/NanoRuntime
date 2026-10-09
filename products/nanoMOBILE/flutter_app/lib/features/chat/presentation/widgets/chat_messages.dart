import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nanoai/core/models/chat_models.dart';
import 'package:nanoai/core/providers/chat_provider.dart';
import 'package:nanoai/core/services/pdf_report_service.dart';
import 'package:nanoai/core/theme/design_tokens.dart';
import 'package:nanoai/core/widgets/live_animations.dart';
import 'package:share_plus/share_plus.dart';

part 'chat_messages_bubble.part.dart';
part 'chat_messages_bubble_user.part.dart';
part 'chat_messages_bubble_assistant.part.dart';
part 'chat_messages_bubble_actions.part.dart';
part 'chat_messages_empty.part.dart';
part 'chat_messages_empty_grid.part.dart';
part 'chat_messages_empty_status.part.dart';
part 'chat_messages_actions.part.dart';
part 'chat_messages_quick_controls.part.dart';
part 'chat_messages_streaming.part.dart';
part 'chat_messages_quick_card.part.dart';
part 'chat_messages_reasoning.part.dart';

MarkdownStyleSheet _buildChatMarkdownStyleSheet(
  BuildContext context, {
  required bool isUser,
}) {
  final colors = Theme.of(context).extension<NanoThemeExtension>()!.colors;
  final isDark = Theme.of(context).brightness == Brightness.dark;

  return MarkdownStyleSheet(
    p: TextStyle(
      color: isUser ? Colors.white : colors.onSurface,
      fontSize: 14.5,
      height: 1.45,
      letterSpacing: -0.1,
      fontFamily: 'Inter',
      fontWeight: FontWeight.w400,
    ),
    h1: TextStyle(
      color: colors.primary,
      fontSize: 19,
      fontWeight: FontWeight.w700,
      height: 1.35,
      letterSpacing: -0.3,
      fontFamily: 'Inter',
    ),
    h2: TextStyle(
      color: colors.primary,
      fontSize: 17,
      fontWeight: FontWeight.w700,
      height: 1.35,
      letterSpacing: -0.2,
      fontFamily: 'Inter',
    ),
    h3: TextStyle(
      color: colors.onSurface,
      fontSize: 15,
      fontWeight: FontWeight.w600,
      height: 1.35,
      fontFamily: 'Inter',
    ),
    strong: TextStyle(
      color: isUser ? Colors.white : colors.onSurface,
      fontWeight: FontWeight.w700,
      fontFamily: 'Inter',
    ),
    em: TextStyle(
      color: isUser ? Colors.white.withValues(alpha: 0.9) : colors.onSurface.withValues(alpha: 0.9),
      fontStyle: FontStyle.italic,
      fontFamily: 'Inter',
    ),
    listBullet: TextStyle(
      color: colors.primary,
      fontSize: 14,
      fontFamily: 'Inter',
    ),
    code: TextStyle(
      backgroundColor: colors.primary.withValues(
        alpha: isDark ? 0.16 : 0.10,
      ),
      color: isDark ? colors.primary : colors.primary,
      fontFamily: 'JetBrainsMono',
      fontSize: 12.5,
      fontWeight: FontWeight.w600,
    ),
    codeblockPadding: const EdgeInsets.all(12),
    codeblockDecoration: BoxDecoration(
      color: isDark ? colors.surface.withValues(alpha: 0.8) : colors.codeBlockBg,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(
        color: colors.outlineVariant.withValues(alpha: 0.35),
        width: 0.8,
      ),
    ),
    blockquote: TextStyle(
      color: colors.onSurfaceVariant,
      fontSize: 13.5,
      fontStyle: FontStyle.italic,
      fontFamily: 'Inter',
    ),
    blockquoteDecoration: BoxDecoration(
      color: colors.primary.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(6),
      border: Border(left: BorderSide(color: colors.primary, width: 3)),
    ),
    tableBorder: TableBorder.all(
      color: colors.outlineVariant.withValues(alpha: 0.35),
      borderRadius: BorderRadius.circular(6),
    ),
    tableHead: TextStyle(
      color: colors.primary,
      fontWeight: FontWeight.w700,
      fontSize: 12.5,
      fontFamily: 'Inter',
    ),
    tableBody: TextStyle(
      color: colors.onSurface,
      fontSize: 12.5,
      fontFamily: 'Inter',
    ),
    tableCellsPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
  );
}

Widget _buildAiBody(BuildContext context, String text) {
  final parsed = parseThought(text);
  final thought = parsed.thought;
  final response = parsed.response;
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (thought != null && thought.trim().isNotEmpty)
        ModelReasoningBlock(thought: thought),
      if (response.trim().isNotEmpty)
        MarkdownBody(
          data: response,
          selectable: true,
          styleSheet: _buildChatMarkdownStyleSheet(context, isUser: false),
        )
      else if (thought != null && response.isEmpty)
        const SizedBox.shrink()
      else
        MarkdownBody(
          data: text.isEmpty ? '...' : text,
          selectable: true,
          styleSheet: _buildChatMarkdownStyleSheet(context, isUser: false),
        ),
    ],
  );
}
