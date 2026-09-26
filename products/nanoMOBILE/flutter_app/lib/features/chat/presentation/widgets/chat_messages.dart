import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:nanoai/core/models/chat_models.dart';
import 'package:nanoai/core/services/pdf_report_service.dart';
import 'package:nanoai/core/theme/design_tokens.dart';
import 'package:nanoai/core/widgets/live_animations.dart';
import 'package:nanoai/core/widgets/nano_owl_avatar.dart';
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
  final isDark = colors is NanoDarkColors;
  return MarkdownStyleSheet(
    p: TextStyle(
      color: isUser ? Colors.white : colors.onSurface.withValues(alpha: 0.96),
      fontSize: 15.5,
      height: 1.48,
      letterSpacing: -0.15,
      fontFamily: 'Inter',
    ),
    h1: TextStyle(
      color: colors.accentCyan,
      fontSize: 20,
      fontWeight: FontWeight.bold,
      height: 1.35,
      letterSpacing: -0.3,
    ),
    h2: TextStyle(
      color: colors.accentCyan,
      fontSize: 18,
      fontWeight: FontWeight.w700,
      height: 1.35,
      letterSpacing: -0.2,
    ),
    h3: TextStyle(
      color: colors.success,
      fontSize: 16,
      fontWeight: FontWeight.w600,
      height: 1.35,
    ),
    strong: TextStyle(
      color: isUser ? Colors.white : colors.onSurface,
      fontWeight: FontWeight.w700,
    ),
    em: TextStyle(
      color: colors.onSurface.withValues(alpha: 0.9),
      fontStyle: FontStyle.italic,
    ),
    listBullet: TextStyle(color: colors.accentCyan, fontSize: 15),
    code: TextStyle(
      backgroundColor: colors.accentCyan.withValues(
        alpha: isDark ? 0.18 : 0.12,
      ),
      color: isDark ? const Color(0xFF67E8F9) : const Color(0xFF0284C7),
      fontFamily: 'JetBrainsMono',
      fontSize: 13.5,
      fontWeight: FontWeight.w600,
    ),
    codeblockPadding: const EdgeInsets.all(14),
    codeblockDecoration: BoxDecoration(
      color: isDark ? const Color(0xFF070D18) : colors.codeBlockBg,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: colors.accentCyan.withValues(alpha: isDark ? 0.30 : 0.18),
        width: 0.9,
      ),
    ),
    blockquote: TextStyle(
      color: colors.onSurface.withValues(alpha: 0.88),
      fontSize: 14.5,
      fontStyle: FontStyle.italic,
    ),
    blockquoteDecoration: BoxDecoration(
      color: colors.accentCyan.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(8),
      border: Border(left: BorderSide(color: colors.accentCyan, width: 3.5)),
    ),
    tableBorder: TableBorder.all(
      color: colors.onSurface.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(8),
    ),
    tableHead: TextStyle(
      color: colors.accentCyan,
      fontWeight: FontWeight.w700,
      fontSize: 13.5,
    ),
    tableBody: TextStyle(
      color: colors.onSurface.withValues(alpha: 0.9),
      fontSize: 13,
    ),
    tableCellsPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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

// ================================================================
// Menú de acciones de mensaje (3 puntos)
// ================================================================

// ================================================================
// Soporte de Razonamiento (DeepSeek <thought>)
// ================================================================

ParsedThoughtText parseThought(String text) {
  final thoughtStart = text.indexOf('<thought>');
  if (thoughtStart == -1) {
    return ParsedThoughtText(response: text);
  }

  final thoughtEnd = text.indexOf('</thought>', thoughtStart);
  if (thoughtEnd == -1) {
    final thought = text.substring(thoughtStart + 9);
    return ParsedThoughtText(thought: thought, response: '');
  }

  final thought = text.substring(thoughtStart + 9, thoughtEnd);
  final response = text.substring(thoughtEnd + 10).trim();
  return ParsedThoughtText(thought: thought, response: response);
}
