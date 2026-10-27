part of 'chat_screen.dart';

/// Un párrafo de lectura: autor + hora + contenido amplio, sin burbujas pesadas.
class _ReadingParagraph extends StatelessWidget {
  const _ReadingParagraph({required this.message, required this.model});

  final ChatMessage message;
  final String model;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<NanoThemeExtension>()!.colors;
    final isUser = message.sender == MessageSender.user;
    final isError = message.status == MessageStatus.error;
    final time =
        '${message.timestamp.hour.toString().padLeft(2, '0')}:'
        '${message.timestamp.minute.toString().padLeft(2, '0')}';
    final label = isUser
        ? 'Tú'
        : (message.source == MessageSource.device
              ? 'Nano · Dispositivo'
              : (model.isEmpty ? 'NanoAI' : model));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              isUser
                  ? Icons.person_rounded
                  : (message.source == MessageSource.device
                        ? Icons.phone_android_rounded
                        : Icons.auto_awesome_rounded),
              size: 13,
              color: isUser
                  ? colors.onSurface.withValues(alpha: 0.45)
                  : colors.accent.withValues(alpha: 0.85),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Inter',
                color: isUser
                    ? colors.onSurface.withValues(alpha: 0.50)
                    : colors.accent.withValues(alpha: 0.85),
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
            const Spacer(),
            Text(
              time,
              style: TextStyle(
                color: colors.onSurface.withValues(alpha: 0.38),
                fontSize: 11,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (isError)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  size: 14,
                  color: colors.danger,
                ),
                const SizedBox(width: 6),
                Text(
                  'Error',
                  style: TextStyle(color: colors.danger, fontSize: 12),
                ),
              ],
            ),
          ),
        if (isUser)
          SelectableText(
            message.text,
            style: _readingBodyStyle(colors, isUser: true),
          )
        else
          _buildReadingAiBody(context, message.text),
        const SizedBox(height: 34),
      ],
    );
  }
}
