part of 'chat_messages.dart';

extension _MessageBubbleAssistantLayout on MessageBubble {
  // QUÉ HACE: ordena encabezado, cuerpo, opciones y acciones del mensaje de IA.
  Widget _buildAssistantMessage(BuildContext context) {
    final colors = Theme.of(context).extension<NanoThemeExtension>()!.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final time =
        '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
    final displayModel = source == MessageSource.device
        ? 'Nano Asistente'
        : (model.isEmpty ? 'Nano AI' : model);
    // AI Message: Free-flowing unboxed layout (ChatGPT / Claude style)
    return Container(
      margin: const EdgeInsets.only(bottom: 22, right: 12),
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
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      colors.glassPrimary.withValues(alpha: 0.90),
                      colors.glassSurface.withValues(alpha: 0.50),
                    ],
                  ),
                  border: Border.all(
                    color: isError
                        ? colors.error.withValues(alpha: 0.60)
                        : colors.primary.withValues(alpha: 0.35),
                    width: 0.9,
                  ),
                ),
                child: Center(
                  child: Icon(
                    isError
                        ? Icons.error_outline_rounded
                        : Icons.auto_awesome_rounded,
                    size: 13,
                    color: isError ? colors.error : colors.primary,
                  ),
                ),
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
                  source == MessageSource.device ? 'SISTEMA' : 'LOCAL IA',
                  style: TextStyle(
                    color: source == MessageSource.device
                        ? colors.accentCyan
                        : colors.primary,
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
