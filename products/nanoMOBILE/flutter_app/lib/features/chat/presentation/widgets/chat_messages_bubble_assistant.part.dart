part of 'chat_messages.dart';

extension _MessageBubbleAssistantLayout on MessageBubble {
  // QUÉ HACE: ordena encabezado, cuerpo, opciones y acciones del mensaje de IA.
  Widget _buildAssistantMessage(BuildContext context) {
    final colors = Theme.of(context).extension<NanoThemeExtension>()!.colors;
    final isDark = colors is NanoDarkColors;
    final time =
        '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
    final displayModel = source == MessageSource.device
        ? 'Nano · Memento'
        : (model.isEmpty ? 'Nano AI' : model);
    // AI Message: Free-flowing unboxed layout (ChatGPT / Claude style)
    return Container(
      margin: const EdgeInsets.only(bottom: 22, right: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header minimalista con avatar del Búho y badge de modelo
          Row(
            children: [
              NanoOwlAvatar(
                size: 26,
                state: isError ? NanoOwlState.error : NanoOwlState.idle,
                enableBreathing: true,
                enableRandomBlink: true,
                enableGlow: false,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  displayModel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.onSurface,
                    fontFamily: 'Inter',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color:
                      (source == MessageSource.device
                              ? colors.accentCyan
                              : colors.primary)
                          .withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color:
                        (source == MessageSource.device
                                ? colors.accentCyan
                                : colors.primary)
                            .withValues(alpha: 0.30),
                    width: 0.8,
                  ),
                ),
                child: Text(
                  source == MessageSource.device ? '⚡ MEMENTO CBR' : 'LOCAL IA',
                  style: TextStyle(
                    color: source == MessageSource.device
                        ? (isDark
                              ? const Color(0xFF67E8F9)
                              : const Color(0xFF0E7490))
                        : (isDark
                              ? const Color(0xFF34D399)
                              : const Color(0xFF059669)),
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              if (tps != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: colors.success.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${tps!.toStringAsFixed(1)} t/s',
                    style: TextStyle(
                      color: colors.success,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),

          // Cuerpo de la respuesta AI (suelta / sin caja)
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: _buildAiBody(context, text),
          ),

          // QUÉ HACE: muestra las opciones generadas para continuar este turno.
          if (suggestions.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildAssistantSuggestions(context, colors, isDark),
          ],
          const SizedBox(height: 10),

          // QUÉ HACE: agrupa las acciones de copia, compartir, exportar y reintentar.
          _buildAssistantActions(context, colors, isDark, time, displayModel),
        ],
      ),
    );
  }
}
