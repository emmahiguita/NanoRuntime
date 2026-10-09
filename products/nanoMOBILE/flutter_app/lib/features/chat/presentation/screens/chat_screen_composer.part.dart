part of 'chat_screen.dart';

/// Barra de redacción 3D Floating Glass Dock de alta fidelidad.
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: _AttachmentPillsStrip(
              attachments: state.attachments,
              onRemove: notifier.removeAttachment,
            ),
          ),

        // 3D Floating Glass Dock
        SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              compact ? 12 : 16,
              2,
              compact ? 12 : 16,
              compact ? 8 : 14,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 32, sigmaY: 32),
                child: Container(
                  height: compact ? 54 : 60,
                  padding: EdgeInsets.symmetric(
                    horizontal: compact ? 6 : 8,
                    vertical: compact ? 4 : 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0B1626).withValues(alpha: 0.82),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: const Color(0xFF7DB7FF).withValues(alpha: 0.16),
                      width: 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.38),
                        blurRadius: 36,
                        offset: const Offset(0, 14),
                      ),
                      BoxShadow(
                        color: const Color(0xFF0099FF).withValues(alpha: 0.08),
                        blurRadius: 16,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // 1. Botón (+) Circular 3D Glass
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(999),
                          onTap: state.generating ? null : _attachFile,
                          child: Container(
                            width: compact ? 36 : 40,
                            height: compact ? 36 : 40,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withValues(alpha: 0.06),
                              border: Border.all(
                                color: const Color(0xFF6EBEFF).withValues(alpha: 0.18),
                                width: 0.8,
                              ),
                            ),
                            child: const Icon(
                              Icons.add_rounded,
                              color: Color(0xFFC2D9ED),
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // 2. Campo de texto limpio
                      Expanded(
                        child: TextField(
                          controller: _textController,
                          focusNode: _focusNode,
                          minLines: 1,
                          maxLines: 1,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 15,
                            color: Color(0xFFF4F8FC),
                            letterSpacing: -0.1,
                          ),
                          cursorColor: const Color(0xFF42D7FF),
                          decoration: const InputDecoration(
                            hintText: 'Escribe un mensaje...',
                            hintStyle: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 15,
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
                            contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
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
                      const SizedBox(width: 4),

                      // 3. Botón Micrófono
                      _buildComposerMicButton(compact: compact, colors: colors),
                      const SizedBox(width: 6),

                      // 4. Botón 3D Luminous Send Button
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
