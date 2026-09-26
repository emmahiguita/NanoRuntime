part of 'chat_messages.dart';

class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.text,
    required this.isUser,
    required this.model,
    required this.timestamp,
    required this.source,
    this.isError = false,
    this.attachmentNames = const [],
    this.suggestions = const [],
    this.tps,
    this.onRetry,
    this.onDelete,
    this.onSuggestionSelected,
  });

  final String text;
  final bool isUser;
  final String model;
  final DateTime timestamp;
  final MessageSource source;
  final bool isError;
  final double? tps;
  final VoidCallback? onRetry;
  final VoidCallback? onDelete;
  final List<String> attachmentNames;
  final List<String> suggestions;
  final ValueChanged<String>? onSuggestionSelected;

  @override
  @override
  Widget build(BuildContext context) =>
      isUser ? _buildUserMessage(context) : _buildAssistantMessage(context);
}
