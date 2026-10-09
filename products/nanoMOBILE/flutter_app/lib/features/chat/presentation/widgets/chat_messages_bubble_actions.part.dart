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

  // QUÉ HACE: renderiza las opciones de sugerencia rápida estilo 3D Glass Capsules.
  Widget _buildAssistantSuggestions(
    BuildContext context,
    NanoColors colors,
    bool isDark,
  ) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: suggestions.map((sug) {
        final icon = _iconForSuggestion(sug);

        return ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  HapticFeedback.lightImpact();
                  onSuggestionSelected?.call(sug);
                },
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF153A4F).withValues(alpha: 0.72),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: const Color(0xFF2ABCFF).withValues(alpha: 0.28),
                      width: 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00A0FF).withValues(alpha: 0.12),
                        blurRadius: 12,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 15, color: const Color(0xFF58D2FE)),
                      const SizedBox(width: 7),
                      Flexible(
                        child: Text(
                          sug,
                          style: const TextStyle(
                            color: Color(0xFFF0F6FC),
                            fontFamily: 'Inter',
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.1,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 11,
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
        const SizedBox(width: 8),
        _QuickActionButton(
          icon: Icons.thumb_up_alt_outlined,
          tooltip: 'Me gusta',
          onTap: () {
            HapticFeedback.lightImpact();
          },
        ),
        const SizedBox(width: 8),
        _QuickActionButton(
          icon: Icons.thumb_down_alt_outlined,
          tooltip: 'No me gusta',
          onTap: () {
            HapticFeedback.lightImpact();
          },
        ),
        const SizedBox(width: 8),
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
                    Icon(Icons.refresh_rounded, size: 14, color: Color(0xFF42D7FF)),
                    SizedBox(width: 4),
                    Text(
                      'Reintentar',
                      style: TextStyle(
                        color: Color(0xFF42D7FF),
                        fontSize: 11.5,
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
