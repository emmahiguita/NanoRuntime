part of 'chat_screen.dart';

/// Hoja de estilo Markdown para el modo lectura (tipografía amplia, cómoda).
MarkdownStyleSheet _buildReadingMarkdownStyleSheet(BuildContext context) {
  final colors = Theme.of(context).extension<NanoThemeExtension>()!.colors;
  return MarkdownStyleSheet(
    p: TextStyle(
      color: colors.onSurface.withValues(alpha: 0.96),
      fontFamily: 'Georgia',
      fontFamilyFallback: const ['serif'],
      fontSize: 18,
      height: 1.72,
      letterSpacing: 0.08,
    ),
    h1: TextStyle(
      color: colors.onSurface,
      fontFamily: 'Georgia',
      fontFamilyFallback: const ['serif'],
      fontSize: 29,
      fontWeight: FontWeight.w700,
      height: 1.22,
    ),
    h2: TextStyle(
      color: colors.onSurface,
      fontFamily: 'Georgia',
      fontFamilyFallback: const ['serif'],
      fontSize: 23,
      fontWeight: FontWeight.w700,
      height: 1.4,
    ),
    h3: TextStyle(
      color: colors.onSurface,
      fontFamily: 'Georgia',
      fontFamilyFallback: const ['serif'],
      fontSize: 20,
      fontWeight: FontWeight.w600,
      height: 1.35,
    ),
    strong: TextStyle(color: colors.onSurface, fontWeight: FontWeight.w700),
    em: TextStyle(
      color: colors.onSurface.withValues(alpha: 0.9),
      fontStyle: FontStyle.italic,
    ),
    listBullet: TextStyle(
      color: colors.accent,
      fontFamily: 'Georgia',
      fontFamilyFallback: const ['serif'],
      fontSize: 18,
    ),
    code: TextStyle(
      backgroundColor: colors.success.withValues(alpha: 0x20 / 0xFF),
      color: colors.success,
      fontFamily: 'monospace',
      fontSize: 15,
    ),
    codeblockPadding: const EdgeInsets.all(14),
    codeblockDecoration: BoxDecoration(
      color: colors.codeBlockBg,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: colors.accent.withValues(alpha: 0.25)),
    ),
    blockquote: TextStyle(
      color: colors.onSurface.withValues(alpha: 0.8),
      fontFamily: 'Georgia',
      fontFamilyFallback: const ['serif'],
      fontSize: 17,
      fontStyle: FontStyle.italic,
    ),
    blockquoteDecoration: BoxDecoration(
      color: colors.quoteBg.withValues(alpha: 0.3),
      borderRadius: BorderRadius.circular(8),
      border: Border(left: BorderSide(color: colors.accent, width: 3)),
    ),
    tableBorder: TableBorder.all(
      color: colors.onSurface.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(6),
    ),
    tableHead: TextStyle(color: colors.accent, fontWeight: FontWeight.w700),
    tableBody: TextStyle(color: colors.onSurface.withValues(alpha: 0.9)),
    tableCellsPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
  );
}

/// Estilo del texto plano del usuario en modo lectura.
TextStyle _readingBodyStyle(NanoColors colors, {required bool isUser}) {
  return TextStyle(
    color: isUser ? colors.onSurface : colors.onSurface.withValues(alpha: 0.96),
    fontFamily: 'Georgia',
    fontFamilyFallback: const ['serif'],
    fontSize: 18,
    height: 1.72,
    letterSpacing: 0.08,
  );
}

/// Cuerpo AI en modo lectura: parsea pensamiento + markdown amplio.
Widget _buildReadingAiBody(BuildContext context, String text) {
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
          styleSheet: _buildReadingMarkdownStyleSheet(context),
        )
      else if (thought == null || response.isEmpty)
        MarkdownBody(
          data: text.isEmpty ? '...' : text,
          selectable: true,
          styleSheet: _buildReadingMarkdownStyleSheet(context),
        ),
    ],
  );
}
