part of 'chat_messages.dart';

class StreamingBubble extends StatelessWidget {
  const StreamingBubble({super.key, required this.text, required this.model});

  final String text;
  final String model;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

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
          // Header minimalista con badge de IA y modelo
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: scheme.surfaceContainerHigh,
                  border: Border.all(color: scheme.outlineVariant, width: 1.0),
                ),
                child: Center(
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    size: 13,
                    color: scheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: NanoStatusBadge(
                  label: model.isEmpty ? 'Nano AI' : model,
                  indicatorColor: scheme.primary,
                  compact: true,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Generando...',
                style: TextStyle(
                  fontFamily: 'Inter',
                  color: scheme.onSurfaceVariant,
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
