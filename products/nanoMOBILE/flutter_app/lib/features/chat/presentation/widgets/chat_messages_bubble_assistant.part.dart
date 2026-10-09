part of 'chat_messages.dart';

extension _MessageBubbleAssistantLayout on MessageBubble {
  Widget _buildAssistantMessage(BuildContext context) {
    final colors = Theme.of(context).extension<NanoThemeExtension>()!.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final time = '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
    final displayModel = source == MessageSource.device ? 'Nano Asistente' : (model.isEmpty ? 'Nano AI' : model);
    final isWeather = NanoRichWeatherCard.hasWeatherData(text);

    return Padding(
      padding: const EdgeInsets.only(bottom: 20, right: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Icono Avatar de Cristal Poliédrico 3D
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Nano3dCrystalIcon(
                  size: 32,
                  isGlowing: !isError,
                  primaryColor: isError ? colors.error : const Color(0xFF4DD7FF),
                ),
              ),
              const SizedBox(width: 10),

              // 2. Tarjeta Flotante 3D Frosted Glass de la Respuesta
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xBA132A42), // Frosted Dark Blue
                            Color(0xD9091725), // Deep Charcoal Blue
                          ],
                        ),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: const Color(0xFF87C8FF).withValues(alpha: 0.16),
                          width: 1.0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.28),
                            blurRadius: 28,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Encabezado interno con timestamp y estado
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                time,
                                style: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF75889B),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),

                          // Cuerpo de la respuesta (Markdown) + Tarjeta Rica si aplica
                          if (isWeather)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: _buildAiBody(context, text),
                                ),
                                const SizedBox(width: 10),
                                const NanoRichWeatherCard(),
                              ],
                            )
                          else
                            _buildAiBody(context, text),

                          const SizedBox(height: 10),

                          // Barra de acciones (Copiar, Thumbs, etc.)
                          _buildAssistantActions(context, colors, isDark, time, displayModel),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          // 3. Chips de Sugerencia Inteligente debajo de la tarjeta
          if (suggestions.isNotEmpty) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.only(left: 42),
              child: _buildAssistantSuggestions(context, colors, isDark),
            ),
          ],
        ],
      ),
    );
  }
}
