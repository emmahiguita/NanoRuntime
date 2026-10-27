part of 'chat_messages.dart';

extension _MessageBubbleUserLayout on MessageBubble {
  Widget _buildUserMessage(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;
    final accent = Theme.of(context).brightness == Brightness.dark
        ? colors.primary
        : colors.tertiary;
    final time =
        '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 28, right: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // 1. Cápsula Luminosa iOS Liquid Glass del Usuario
          Flexible(
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomLeft: Radius.circular(18),
                bottomRight: Radius.circular(5),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 580),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [accent, colors.primary],
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(18),
                      topRight: Radius.circular(18),
                      bottomLeft: Radius.circular(18),
                      bottomRight: Radius.circular(5),
                    ),
                    border: Border.all(
                      color: colors.onAccent.withValues(alpha: 0.38),
                      width: 0.8,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.24),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 13,
                    vertical: 8.5,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (attachmentNames.isNotEmpty) ...[
                        Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: attachmentNames
                              .map(
                                (name) => Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 2.5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: colors.background.withValues(
                                      alpha: 0.22,
                                    ),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: colors.onAccent.withValues(
                                        alpha: 0.25,
                                      ),
                                      width: 0.5,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.attach_file_rounded,
                                        size: 13,
                                        color: colors.onAccent,
                                      ),
                                      const SizedBox(width: 3),
                                      Text(
                                        name,
                                        style: TextStyle(
                                          color: colors.onAccent,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                        const SizedBox(height: 5),
                      ],
                      MarkdownBody(
                        data: text,
                        selectable: true,
                        styleSheet: _buildChatMarkdownStyleSheet(
                          context,
                          isUser: true,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            time,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              color: colors.onAccent.withValues(alpha: 0.9),
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 3),
                          Icon(
                            Icons.done_all_rounded,
                            size: 14,
                            color: colors.onAccent,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),

          // 2. Avatar de Cristal Translúcido del Usuario
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colors.surfaceVariant.withValues(alpha: 0.82),
              border: Border.all(
                color: colors.outlineVariant.withValues(alpha: 0.72),
                width: 0.8,
              ),
              boxShadow: [
                BoxShadow(
                  color: colors.primary.withValues(alpha: 0.13),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Center(
              child: Icon(
                Icons.person_rounded,
                size: 15,
                color: colors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
