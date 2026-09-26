part of 'chat_messages.dart';

class StreamingBubble extends StatelessWidget {
  const StreamingBubble({super.key, required this.text, required this.model});

  final String text;
  final String model;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<NanoThemeExtension>()!.colors;

    final parsed = parseThought(text);
    final thought = parsed.thought;
    final response = parsed.response;

    final Widget body;
    if (text.isEmpty) {
      body = const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Align(
          alignment: Alignment.centerLeft,
          child: ThinkingIndicator(),
        ),
      );
    } else {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (thought != null && thought.trim().isNotEmpty)
            ModelReasoningBlock(thought: thought, initiallyExpanded: true),
          if (response.trim().isNotEmpty)
            MarkdownBody(
              data: response,
              styleSheet: _buildChatMarkdownStyleSheet(context, isUser: false),
            )
          else if (thought != null && response.isEmpty)
            const SizedBox.shrink()
          else
            MarkdownBody(
              data: text.isEmpty ? '...' : text,
              styleSheet: _buildChatMarkdownStyleSheet(context, isUser: false),
            ),
          const SizedBox(height: 6),
          const StreamingCursor(),
        ],
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 20, right: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header minimalista con Búho en modo thinking y badge seguro contra overflow
          Row(
            children: [
              NanoOwlAvatar(
                size: 26,
                state: response.isNotEmpty
                    ? NanoOwlState.responding
                    : NanoOwlState.thinking,
                enableBreathing: true,
                enableGlow: true,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: colors.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: colors.accent.withValues(alpha: 0.3),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: colors.accent,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          model.isEmpty ? 'Nano AI' : model,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            color: colors.accent,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Generando...',
                style: TextStyle(
                  fontFamily: 'Inter',
                  color: colors.onSurface.withValues(alpha: 0.45),
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Padding(padding: const EdgeInsets.only(left: 4), child: body),
        ],
      ),
    );
  }
}
