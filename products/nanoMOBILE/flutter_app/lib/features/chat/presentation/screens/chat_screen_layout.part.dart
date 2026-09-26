part of 'chat_screen.dart';

extension _ChatScreenLayout on _ChatScreenState {
  Widget _buildChatScreen(BuildContext context) {
    final colors = Theme.of(context).extension<NanoThemeExtension>()!.colors;
    final state = ref.watch(chatProvider);
    final notifier = ref.read(chatProvider.notifier);
    final mediaQuery = MediaQuery.of(context);
    final screenSize = mediaQuery.size;
    // ORIENTATION-FIX: usa Orientation real del dispositivo (no width > height).
    // El teclado reduce la altura disponible en portrait, lo que hace que
    // width > height sea verdadero erróneamente y activa el layout landscape.
    final isLandscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    final isCompactLandscape = isLandscape && screenSize.height < 520;

    // Auto-scroll al fondo con cada mensaje nuevo y al arrancar generación.
    ref.listen(chatProvider.select((s) => s.messages.length), (_, __) {
      _scrollToBottom();
    });
    ref.listen(chatProvider.select((s) => s.generating), (_, __) {
      _scrollToBottom();
    });
    // Política §12: el tool-calling pidió una escritura externa — diálogo de
    // confirmación obligatorio (sin dismiss lateral: decisión del humano).
    ref.listen(chatProvider.select((s) => s.pendingTool), (prev, next) {
      if (next != null && prev != next) {
        _showToolConfirmDialog(next);
      }
    });

    return NanoInputScope(
      scopeId: 'chat',
      hint: 'Escribe un mensaje a Nano AI...',
      // NAV-BAR-FIX-01 — el texto dictado llega a la barra universal por aquí.
      initialText: _dictatedText.isEmpty ? null : _dictatedText,
      onSubmit: (text) {
        notifier.send(text);
        // El envío consumió el dictado: la barra se limpia sola (clearOnSubmit).
        setState(() => _dictatedText = '');
      },
      onVoice: _toggleMic,
      onAttach: _attachFile,
      isGenerating: state.generating,
      // NAV-BAR-FIX-05 — el orbe de la barra refleja el estado real del
      // micrófono (stop rojo pulsante mientras escucha).
      isListening: _listening,
      onStop: notifier.stop,
      keepFocusOnSubmit: true,
      // En horizontal el compositor no se oculta solo: escribir y enviar
      // sigue disponible sin depender de una píldora minimizada.
      keepDockVisible: true,
      child: NanoScreenShell(
        title: 'Chat',
        hideHeader: _isReadingMode,
        resizeToAvoidBottomInset: false,
        trailing: _isReadingMode
            ? null
            : _chatActions(state, notifier, colors, landscape: isLandscape),
        body: Stack(
          fit: StackFit.expand,
          children: [
            // QUÉ HACE: usa la superficie del tema como lienzo sólido del chat.
            // POR QUÉ: elimina el degradado decorativo que ensucia la lectura.
            Positioned.fill(
              child: RepaintBoundary(
                child: ColoredBox(color: Theme.of(context).colorScheme.surface),
              ),
            ),
            Positioned.fill(
              child: _isReadingMode
                  ? _ReadingMode(
                      messages: state.messages,
                      model: state.activeModel,
                      onExit: () => setState(() => _isReadingMode = false),
                    )
                  : isLandscape
                  ? _buildLandscapeChat(state, notifier, mediaQuery)
                  : Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: isCompactLandscape ? 1440 : 1400,
                        ),
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: _messageList(
                                state,
                                notifier,
                                bottomPadding: kNanoBarScrollReserve,
                                emptyBottomPadding: 24,
                                sidePadding: isCompactLandscape ? 10.0 : 18.0,
                              ),
                            ),
                            if (state.attachments.isNotEmpty)
                              Positioned(
                                left: isCompactLandscape ? 12 : 24,
                                right: isCompactLandscape ? 12 : 24,
                                bottom: 12,
                                child: _AttachmentPillsStrip(
                                  attachments: state.attachments,
                                  onRemove: notifier.removeAttachment,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
