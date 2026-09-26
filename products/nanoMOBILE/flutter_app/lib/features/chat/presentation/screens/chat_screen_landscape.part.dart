part of 'chat_screen.dart';

extension _ChatScreenLandscape on _ChatScreenState {
  /// UI-REV-16 — chat horizontal: la lista de mensajes domina TODO el ancho
  /// (sin panel lateral de escritura; la barra universal del shell sigue
  /// siendo el punto de escritura) y las acciones del chat flotan en vidrio
  /// arriba a la derecha. Los adjuntos pendientes se muestran en una franja
  /// inferior. Nada se solapa: la lista reserva sus despejes.
  Widget _buildLandscapeChat(
    ChatState state,
    ChatNotifier notifier,
    MediaQueryData mediaQuery,
  ) {
    final screenWidth = mediaQuery.size.width;
    final targetWidth = screenWidth >= 900
        ? screenWidth * 0.60
        : screenWidth * 0.82;
    final contentWidth = targetWidth.clamp(360.0, 760.0).toDouble();
    final availableSide = (screenWidth - contentWidth) / 2;
    final sidePadding = availableSide > 12.0 ? availableSide : 12.0;
    final attachmentTopPadding = state.attachments.isEmpty ? 8.0 : 58.0;

    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: _messageList(
            state,
            notifier,
            topPadding: attachmentTopPadding,
            bottomPadding: kNanoBarScrollReserve,
            emptyBottomPadding: 24,
            sidePadding: sidePadding,
          ),
        ),
        if (state.attachments.isNotEmpty)
          Positioned(
            top: 8,
            left: sidePadding,
            right: sidePadding,
            child: Align(
              alignment: Alignment.topCenter,
              child: _AttachmentPillsStrip(
                attachments: state.attachments,
                onRemove: notifier.removeAttachment,
              ),
            ),
          ),
      ],
    );
  }

  /// UI-REV-14 — lista de mensajes compartida vertical/horizontal. Un solo
  /// builder para las dos orientaciones; solo cambian los despejes (inferior
  /// para la barra en vertical, superior para la toolbar flotante en
  /// horizontal) y el lateral.
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
