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
                  primaryColor: isError ? colors.error : colors.primary,
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
                          // Encabezado interno con timestamp
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                time,
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: colors.onSurfaceVariant,
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
