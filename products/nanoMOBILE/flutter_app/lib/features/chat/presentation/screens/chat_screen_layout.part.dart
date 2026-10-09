part of 'chat_screen.dart';

// QUÉ HACE:
// Orquesta la disposición visual principal de la pantalla de chat en modo vertical (Portrait).
//
// CÓMO FUNCIONA:
// - Supervisa el flujo de mensajes y estado de generación conectando listeners a `chatProvider`.
// - Delega la composición inferior a `_buildComposerBar` (en `chat_screen_composer.part.dart`).
// - Cambia limpiamente al modo lectura `_ReadingMode` o al modo horizontal `_buildLandscapeChat`.
// - Sincroniza el búho flotante con el estado de inferencia local.
//
// POR QUÉ:
// Aplica principios SOLID y Clean Architecture (< 120 líneas), garantizando separación estricta
// de responsabilidades, evitando cuellos de botella en la renderización y previniendo procesos zombies.
extension _ChatScreenLayout on _ChatScreenState {
  /// QUÉ HACE: Construye la estructura visual principal del chat con shell, mensajes y composer.
  /// CÓMO FUNCIONA: Escucha cambios de generación para auto-scroll y actualiza la actividad del búho.
  /// POR QUÉ: Ofrece una experiencia responsiva tanto en teléfonos verticales como al rotar la pantalla.
  Widget _buildChatScreen(BuildContext context) {
    final colors = Theme.of(context).extension<NanoThemeExtension>()!.colors;
    final state = ref.watch(chatProvider);
    final notifier = ref.read(chatProvider.notifier);
    final mediaQuery = MediaQuery.of(context);
    final screenSize = mediaQuery.size;

    // ORIENTATION-FIX: usa Orientation real del dispositivo (no width > height).
    // El teclado reduce la altura disponible en portrait, lo que hace que
    // width > height sea verdadero erróneamente y activaría el layout landscape por error.
    final isLandscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    final isCompactLandscape = isLandscape && screenSize.height < 520;

    // Auto-scroll al fondo con cada mensaje nuevo y al arrancar generación.
    ref.listen(chatProvider.select((s) => s.messages.length), (_, __) {
      _scrollToBottom();
    });
    ref.listen(chatProvider.select((s) => s.generating), (_, next) {
      _scrollToBottom();
      // Sincronizar el búho flotante con la generación del chat
      NanoFloatingWrapper.activeController?.setActivity(
        next ? NanoActivity.thinking : NanoActivity.idle,
      );
    });
    // Política §12: confirmación obligatoria para tool-calling en dispositivo.
    ref.listen(chatProvider.select((s) => s.pendingTool), (prev, next) {
      if (next != null && prev != next) {
        _showToolConfirmDialog(next);
      }
    });

    return NanoInputScope(
      scopeId: 'chat',
      hint: 'Escribe un mensaje…',
      controller: _textController,
      focusNode: _focusNode,
      initialText: _dictatedText.isEmpty ? null : _dictatedText,
      onSubmit: (text) {
        notifier.send(text);
        _textController.clear();
        setState(() => _dictatedText = '');
      },
      onVoice: _toggleMic,
      onAttach: _attachFile,
      isGenerating: state.generating,
      isListening: _listening,
      onStop: notifier.stop,
      keepFocusOnSubmit: true,
      keepDockVisible: true,
      child: NanoScreenShell(
        title: 'Chat',
        backgroundColor: Theme.of(context).colorScheme.surface,
        hideHeader: _isReadingMode,
        resizeToAvoidBottomInset: true,
        trailing: _isReadingMode
            ? null
            : _chatActions(state, notifier, colors, landscape: isLandscape),
        body: Stack(
          fit: StackFit.expand,
          children: [
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
                  : Column(
                      children: [
                        Expanded(
                          child: Center(
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: isCompactLandscape ? 1440 : 1400,
                              ),
                              child: _messageList(
                                state,
                                notifier,
                                bottomPadding: 16.0,
                                emptyBottomPadding: 24,
                                sidePadding: isCompactLandscape ? 10.0 : 18.0,
                              ),
                            ),
                          ),
                        ),
                        _buildComposerBar(context, state, notifier, colors),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
