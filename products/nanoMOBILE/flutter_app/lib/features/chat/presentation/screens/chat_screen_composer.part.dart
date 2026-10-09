part of 'chat_screen.dart';

/// Barra de redacción compacta estilo iOS Translucent Glass Dock.
extension _ChatScreenComposer on _ChatScreenState {
  Widget _buildComposerBar(
    BuildContext context,
    ChatState state,
    ChatNotifier notifier,
    NanoColors colors, {
    bool compact = false,
  }) {
    final hasText = _textController.text.trim().isNotEmpty;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Tira de archivos adjuntos
        if (state.attachments.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
            child: _AttachmentPillsStrip(
              attachments: state.attachments,
              onRemove: notifier.removeAttachment,
            ),
          ),

        // iOS Translucent Glass Dock
        SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              compact ? 8 : 12,
              1,
              compact ? 8 : 12,
              compact ? 6 : 8,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(26),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                child: Container(
                  height: compact ? 44 : 48,
                  padding: EdgeInsets.symmetric(
                    horizontal: compact ? 4 : 6,
                    vertical: compact ? 3 : 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F1E2E).withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.16),
                      width: 0.8,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // 1. Botón (+) Circular iOS Glass
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(999),
                          onTap: state.generating ? null : _attachFile,
                          child: Container(
                            width: compact ? 30 : 34,
                            height: compact ? 30 : 34,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withValues(alpha: 0.08),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.15),
                                width: 0.7,
                              ),
                            ),
                            child: const Icon(
                              Icons.add_rounded,
                              color: Color(0xFFC2D9ED),
                              size: 18,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),

                      // 2. Campo de texto limpio
                      Expanded(
                        child: TextField(
                          controller: _textController,
                          focusNode: _focusNode,
                          minLines: 1,
                          maxLines: 1,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 14,
                            color: Color(0xFFF4F8FC),
                            letterSpacing: -0.1,
                          ),
                          cursorColor: const Color(0xFF42D7FF),
                          decoration: const InputDecoration(
                            hintText: 'Escribe un mensaje...',
                            hintStyle: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                              color: Color(0xFF7F91A5),
                            ),
                            filled: false,
                            fillColor: Colors.transparent,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            disabledBorder: InputBorder.none,
                            errorBorder: InputBorder.none,
                            focusedErrorBorder: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                          ),
                          textInputAction: TextInputAction.send,
                          onSubmitted: (text) {
                            if (text.trim().isNotEmpty && !state.generating) {
                              notifier.send(text.trim());
                              _textController.clear();
                              setState(() => _dictatedText = '');
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 2),

                      // 3. Botón Micrófono
                      _buildComposerMicButton(compact: compact, colors: colors),
                      const SizedBox(width: 4),

                      // 4. Botón Send Compacto
                      _buildComposerSendButton(
                        isGenerating: state.generating,
                        hasText: hasText,
                        compact: compact,
                        isDark: true,
                        colors: colors,
                        onStop: notifier.stop,
                        onSend: notifier.send,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
