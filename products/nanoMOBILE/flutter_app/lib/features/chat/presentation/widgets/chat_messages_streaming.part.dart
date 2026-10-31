part of 'chat_messages.dart';

/// Burbuja de streaming durante la generación de respuestas de IA.
///
/// **QUÉ HACE:**
/// Renderiza la respuesta activa dentro de la misma tarjeta Frosted Acrylic Glass
/// de [MessageBubble], con avatar oficial de Nano y estado de generación vivo.
///
/// **CÓMO FUNCIONA:**
/// Integra [ModelReasoningBlock] para pensamientos (`<thought>`), [ThinkingIndicator]
/// si aún no hay tokens, y [NanoAnimatedStreamingText] con estela cromática dinámica.
///
/// **POR QUÉ:**
/// Elimina el parpadeo de layout al terminar la inferencia y traslada la experiencia
/// fluida de `expo-animated-streaming-text` en coherencia con el diseño de Nano Mobile.
class StreamingBubble extends StatelessWidget {
  const StreamingBubble({super.key, required this.text, required this.model});

  final String text;
  final String model;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<NanoThemeExtension>()!.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final parsed = parseThought(text);
    final thought = parsed.thought;
    final response = parsed.response;
    final displayModel = model.isEmpty ? 'Nano AI' : model;

    final Widget bodyContent;
    if (text.isEmpty) {
      bodyContent = const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Align(
          alignment: Alignment.centerLeft,
          child: ThinkingIndicator(),
        ),
      );
    } else {
      bodyContent = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (thought != null && thought.trim().isNotEmpty) ...[
            ModelReasoningBlock(thought: thought, initiallyExpanded: true),
            const SizedBox(height: 8),
          ],
          if (response.trim().isNotEmpty)
            NanoAnimatedStreamingText(text: response)
          else if (thought != null && response.isEmpty)
            const SizedBox.shrink()
          else
            NanoAnimatedStreamingText(text: text),
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12, right: 8, left: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Avatar oficial de Nano AI sobre cristal
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: NanoBrandAvatar(
                  size: 28,
                  isError: false,
                ),
              ),
              const SizedBox(width: 8),

              // 2. Tarjeta Flotante Frosted Acrylic Glass (idéntica a MessageBubble)
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(13, 9, 13, 11),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            colors.surface.withValues(
                              alpha: isDark ? 0.82 : 0.94,
                            ),
                            colors.backgroundElevated.withValues(
                              alpha: isDark ? 0.78 : 0.96,
                            ),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: colors.outlineVariant.withValues(alpha: 0.72),
                          width: 0.8,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: colors.background.withValues(
                              alpha: isDark ? 0.18 : 0.05,
                            ),
                            blurRadius: 18,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Encabezado de generación con badge semántico
                          Row(
                            children: [
                              Flexible(
                                child: NanoStatusBadge(
                                  label: displayModel,
                                  indicatorColor: colors.primary,
                                  compact: true,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Generando...',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  color: colors.onSurfaceVariant,
                                  fontSize: 11,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          bodyContent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
