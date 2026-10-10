part of 'chat_messages.dart';

extension _MessageBubbleAssistantLayout on MessageBubble {
  Widget _buildAssistantMessage(BuildContext context) {
    final colors = Theme.of(context).extension<NanoThemeExtension>()!.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final time =
        '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
    final displayModel = source == MessageSource.device
        ? 'Nano Asistente'
        : (model.isEmpty ? 'Nano AI' : model);
    final liveWeather = isLatest
        ? AmbientContextService.instance.latestForUi
        : null;
    final weather = liveWeather == null
        ? NanoRichWeatherCard.parse(text)
        : NanoWeatherData.fromAmbient(liveWeather);
    final liveArea =
        '${liveWeather?.providerArea ?? ''} ${liveWeather?.location ?? ''}'
            .toLowerCase();
    final showSiata =
        NanoSiataRadarCard.shouldShow(text) ||
        (weather != null &&
            (liveArea.contains('medellín') ||
                liveArea.contains('medellin') ||
                liveArea.contains('valle de aburrá') ||
                liveArea.contains('valle de aburra')));

    return Padding(
      padding: const EdgeInsets.only(bottom: 12, right: 8, left: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Icono Avatar de Cristal Poliédrico 3D Compacto
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Nano3dCrystalIcon(
                  size: 28,
                  isGlowing: !isError,
                  primaryColor: isError
                      ? colors.error
                      : const Color(0xFF4DD7FF),
                ),
              ),
              const SizedBox(width: 8),

              // 2. Tarjeta Flotante iOS Frosted Acrylic Glass de la Respuesta
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(13, 9, 13, 9),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0x73112236), // Frosted Translucent Dark Glass
                            Color(0x8C091624), // Deep Translucent Acrylic
                          ],
                        ),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.13),
                          width: 0.8,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.20),
                            blurRadius: 18,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Encabezado interno con timestamp
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                time,
                                style: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF75889B),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 1),

                          // El texto conserva todo el ancho. Las tarjetas
                          // enriquecidas viven debajo; nunca compiten con la
                          // lectura ni forman una columna estrecha.
                          _buildAiBody(context, text),
                          if (weather != null) ...[
                            const SizedBox(height: 10),
                            NanoRichWeatherCard(data: weather),
                          ],
                          if (showSiata) ...[
                            const SizedBox(height: 10),
                            const NanoSiataRadarCard(),
                          ],

                          const SizedBox(height: 8),

                          // Barra de acciones compacta (Copiar, Thumbs, etc.)
                          _buildAssistantActions(
                            context,
                            colors,
                            isDark,
                            time,
                            displayModel,
                          ),
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
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 36),
              child: _buildAssistantSuggestions(context, colors, isDark),
            ),
          ],
        ],
      ),
    );
  }
}
