part of 'chat_screen.dart';

// QUÉ HACE:
// Adapta la interfaz de chat al modo horizontal (Landscape) en dispositivos móviles y tabletas.
//
// CÓMO FUNCIONA:
// - Calcula un ancho ergonómico centralizado (contentWidth) según la resolución disponible.
// - Distribuye el padding lateral para que los mensajes no se estiren de extremo a extremo de forma ilegible.
// - Invoca `_buildComposerBar(compact: true)` con menor altura y controles optimizados para pantallas apaisadas.
// - Maneja el scroll elástico con `BouncingScrollPhysics` y burbujas interactivas con acciones rápidas (`suggestions`).
//
// POR QUÉ:
// Asegura una experiencia visual y táctil profesional de primer nivel en horizontal (< 150 líneas),
// cumpliendo los principios de diseño Material 3 Expressive para móviles.
extension _ChatScreenLandscape on _ChatScreenState {
  /// QUÉ HACE: Renderiza la disposición en columna adaptada para pantallas apaisadas.
  /// CÓMO FUNCIONA: Limita el ancho de la lista de mensajes y centra la barra de redacción compacta.
  /// POR QUÉ: Mantiene la legibilidad del texto en líneas de 60-80 caracteres y previene desbordamientos.
  Widget _buildLandscapeChat(
    ChatState state,
    ChatNotifier notifier,
    MediaQueryData mediaQuery,
  ) {
    final colors = Theme.of(context).extension<NanoThemeExtension>()!.colors;
    final screenWidth = mediaQuery.size.width;
    final targetWidth = screenWidth >= 900
        ? screenWidth * 0.65
        : screenWidth * 0.85;
    final contentWidth = targetWidth.clamp(360.0, 840.0).toDouble();
    final availableSide = (screenWidth - contentWidth) / 2;
    final sidePadding = availableSide > 12.0 ? availableSide : 12.0;

    return Column(
      children: [
        Expanded(
          child: _messageList(
            state,
            notifier,
            topPadding: 8.0,
            bottomPadding: 8.0,
            emptyBottomPadding: 16.0,
            sidePadding: sidePadding,
          ),
        ),
        Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: contentWidth),
            child: _buildComposerBar(
              context,
              state,
              notifier,
              colors,
              compact: true,
            ),
          ),
        ),
      ],
    );
  }

  /// QUÉ HACE: Lista virtualizada de mensajes compartida entre modo vertical y horizontal.
  /// CÓMO FUNCIONA: Renderiza burbujas de usuario, asistente, streaming en vivo o estado vacío (EmptyChat).
  /// POR QUÉ: Evita duplicación de código (DRY) y soporta sugerencias interactivas para responder sin escribir.
  Widget _messageList(
    ChatState state,
    ChatNotifier notifier, {
    required double bottomPadding,
    required double emptyBottomPadding,
    required double sidePadding,
    double topPadding = 8,
  }) {
    if (state.messages.isEmpty) {
      return Padding(
        padding: EdgeInsets.only(bottom: emptyBottomPadding),
        child: EmptyChat(
          engineOnline: state.engineOnline,
          hasModel: state.activeModelPath != null,
          onSuggestion: (text) {
            notifier.send(text);
          },
          onRetry: () => notifier.refreshEngine(),
          onGoModels: () => context.go('/models'),
        ),
      );
    }
    return ListView.builder(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        sidePadding,
        topPadding,
        sidePadding,
        bottomPadding,
      ),
      itemCount: state.messages.length + (state.generating ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == state.messages.length) {
          return StreamingBubble(
            text: state.streamingText,
            model: state.activeModel,
          );
        }

        final message = state.messages[index];
        final isUser = message.sender == MessageSender.user;
        final isError = message.status == MessageStatus.error;

        return AnimatedMessageEntry(
          key: ValueKey(message.id),
          isUser: isUser,
          child: GestureDetector(
            onLongPress: state.generating
                ? null
                : () => _showDeleteDialog(notifier, message),
            child: MessageBubble(
              text: message.text,
              isUser: isUser,
              model: state.activeModel,
              timestamp: message.timestamp,
              isError: isError,
              source: message.source,
              attachmentNames: message.attachmentNames,
              suggestions: message.suggestions,
              tps: message.tps,
              isLatest: index == state.messages.length - 1,
              onRetry: isError && !state.generating
                  ? () => notifier.retry(message.id)
                  : null,
              onDelete: state.generating
                  ? null
                  : () => _showDeleteDialog(notifier, message),
              onSuggestionSelected: state.generating
                  ? null
                  : (sug) => notifier.send(sug),
            ),
          ),
        );
      },
    );
  }
}
