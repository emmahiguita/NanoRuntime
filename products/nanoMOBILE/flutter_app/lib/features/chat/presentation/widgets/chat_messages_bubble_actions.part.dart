part of 'chat_messages.dart';

extension _MessageBubbleAssistantActions on MessageBubble {
  IconData _iconForSuggestion(String label) {
    final lower = label.toLowerCase();
    if (lower.contains('profundiz') || lower.contains('detalle') || lower.contains('más')) {
      return Icons.menu_book_rounded;
    }
    if (lower.contains('ejemplo') || lower.contains('práctico') || lower.contains('idea')) {
      return Icons.lightbulb_outline_rounded;
    }
    return Icons.navigate_next_rounded;
  }

  // QUÉ HACE: renderiza las opciones de sugerencia rápida estilo iOS Translucent Glass Capsules.
  Widget _buildAssistantSuggestions(
    BuildContext context,
    NanoColors colors,
    bool isDark,
  ) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: suggestions.map((sug) {
        final icon = _iconForSuggestion(sug);

        return ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  HapticFeedback.lightImpact();
                  onSuggestionSelected?.call(sug);
                },
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF143048).withValues(alpha: 0.40),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xFF38BDF8).withValues(alpha: 0.22),
                      width: 0.75,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00A0FF).withValues(alpha: 0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 13, color: const Color(0xFF58D2FE)),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          sug,
                          style: const TextStyle(
                            color: Color(0xFFF0F6FC),
                            fontFamily: 'Inter',
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.1,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 9.5,
                        color: Color(0xFF58D2FE),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // QUÉ HACE: muestra acciones de feedback y utilidades (copiar, like, dislike, compartir).
  Widget _buildAssistantActions(
    BuildContext context,
    NanoColors colors,
    bool isDark,
    String time,
    String displayModel,
  ) => Row(
    children: [
      if (!isError) ...[
        _QuickActionButton(
          icon: Icons.copy_rounded,
          tooltip: 'Copiar respuesta',
          onTap: () async {
            HapticFeedback.lightImpact();
            await Clipboard.setData(ClipboardData(text: text));
            if (!context.mounted) return;
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                const SnackBar(
                  content: Text('Texto copiado al portapapeles'),
                  duration: Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                ),
              );
          },
        ),
        const SizedBox(width: 6),
        _QuickActionButton(
          icon: Icons.thumb_up_alt_outlined,
          tooltip: 'Me gusta',
          onTap: () {
            HapticFeedback.lightImpact();
          },
        ),
        const SizedBox(width: 6),
        _QuickActionButton(
          icon: Icons.thumb_down_alt_outlined,
          tooltip: 'No me gusta',
          onTap: () {
            HapticFeedback.lightImpact();
          },
        ),
        const SizedBox(width: 6),
        MessageActions(
          text: text,
          model: displayModel,
          timestamp: timestamp,
          onDelete: onDelete,
        ),
      ],
      if (onRetry != null) ...[
        const Spacer(),
        Semantics(
          button: true,
          label: 'Reintentar mensaje',
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              onTap: onRetry,
              borderRadius: BorderRadius.circular(10),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.refresh_rounded, size: 13, color: Color(0xFF42D7FF)),
                    SizedBox(width: 4),
                    Text(
                      'Reintentar',
                      style: TextStyle(
                        color: Color(0xFF42D7FF),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    ],
  );
}
