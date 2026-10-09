part of 'chat_screen.dart';

extension _ChatScreenLayout on _ChatScreenState {
  Widget _buildChatScreen(BuildContext context) {
    final colors = Theme.of(context).extension<NanoThemeExtension>()!.colors;
    final state = ref.watch(chatProvider);
    final notifier = ref.read(chatProvider.notifier);
    final mediaQuery = MediaQuery.of(context);
    final screenSize = mediaQuery.size;
    final isLandscape = MediaQuery.orientationOf(context) == Orientation.landscape;
    final isCompactLandscape = isLandscape && screenSize.height < 520;

    ref.listen(chatProvider.select((s) => s.messages.length), (_, __) => _scrollToBottom());
    ref.listen(chatProvider.select((s) => s.generating), (_, next) {
      _scrollToBottom();
      NanoFloatingWrapper.activeController?.setActivity(next ? NanoActivity.thinking : NanoActivity.idle);
    });
    ref.listen(chatProvider.select((s) => s.pendingTool), (prev, next) {
      if (next != null && prev != next) _showToolConfirmDialog(next);
    });

    return NanoInputScope(
      scopeId: 'chat',
      hint: 'Escribe un mensaje...',
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
        backgroundColor: const Color(0xFF07111C),
        hideHeader: _isReadingMode,
        resizeToAvoidBottomInset: true,
        trailing: _isReadingMode ? null : _chatActions(state, notifier, colors, landscape: isLandscape),
        body: Stack(
          fit: StackFit.expand,
          children: [
            // 1. Z0/Z1 Fondo Espacial con Iluminación Subsuperficial Cyan/Navy
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFF07111C), // Deep Navy Black
                      Color(0xFF0D1724), // Subtle Charcoal Blue
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: -80,
              right: -40,
              child: Container(
                width: 320,
                height: 320,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF00A3FF).withValues(alpha: 0.12),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            // 2. Contenido del Chat / Modo Lectura / Modo Landscape
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
                            // Tarjeta Flotante 3D del Modelo Activo
                            NanoActiveModelGlassCard(
                              modelName: state.activeModel,
                              isOnline: state.engineOnline,
                              isGenerating: state.generating,
                              tps: state.messages.isNotEmpty ? state.messages.last.tps : 5.9,
                              onTap: () => context.go('/models'),
                            ),

                            // Lista de Conversación con Scroll
                            Expanded(
                              child: Center(
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(maxWidth: isCompactLandscape ? 1440 : 1400),
                                  child: _messageList(
                                    state,
                                    notifier,
                                    bottomPadding: 8.0,
                                    emptyBottomPadding: 16,
                                    sidePadding: isCompactLandscape ? 8.0 : 10.0,
                                  ),
                                ),
                              ),
                            ),

                            // iOS Floating Glass Dock de Composición
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
