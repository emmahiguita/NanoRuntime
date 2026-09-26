part of 'chat_messages.dart';

extension _MessageBubbleAssistantActions on MessageBubble {
  // QUÉ HACE: renderiza las opciones de continuación sin duplicar la burbuja.
  Widget _buildAssistantSuggestions(
    BuildContext context,
    NanoColors colors,
    bool isDark,
  ) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: suggestions.map((sug) {
        final pillColor = isDark ? const Color(0xFF10B981) : colors.accent;
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => onSuggestionSelected?.call(sug),
            borderRadius: BorderRadius.circular(14),
            splashColor: pillColor.withValues(alpha: 0.20),
            highlightColor: pillColor.withValues(alpha: 0.10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: pillColor.withValues(alpha: isDark ? 0.12 : 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: pillColor.withValues(alpha: isDark ? 0.28 : 0.22),
                  width: 0.8,
                ),
                boxShadow: [
                  BoxShadow(
                    color: pillColor.withValues(alpha: isDark ? 0.08 : 0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      sug,
                      style: TextStyle(
                        color: colors.onSurface,
                        fontFamily: 'Inter',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.1,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 10,
                    color: pillColor.withValues(alpha: 0.85),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // QUÉ HACE: muestra acciones disponibles para la respuesta y su hora.
  Widget _buildAssistantActions(
    BuildContext context,
    NanoColors colors,
    bool isDark,
    String time,
    String displayModel,
  ) => Row(
    children: [
      Text(
        time,
        style: TextStyle(
          color: colors.onSurface.withValues(alpha: 0.45),
          fontSize: 10.5,
          fontWeight: FontWeight.w500,
          letterSpacing: -0.1,
        ),
      ),
      const SizedBox(width: 12),
      if (!isError) ...[
        _QuickActionButton(
          icon: Icons.copy_rounded,
          tooltip: 'Copiar respuesta',
          onTap: () async {
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
        const SizedBox(width: 4),
        _QuickActionButton(
          icon: Icons.share_rounded,
          tooltip: 'Compartir',
          onTap: () => SharePlus.instance.share(
            ShareParams(text: text, subject: 'Respuesta Nano AI'),
          ),
        ),
        const SizedBox(width: 4),
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
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.refresh_rounded,
                      size: 14,
                      color: colors.accentCyan,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Reintentar',
                      style: TextStyle(
                        color: colors.accentCyan,
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
