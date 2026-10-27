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
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
                    color: colors.surface.withValues(
                      alpha: isDark ? 0.82 : 0.92,
                    ),
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(
                      color: colors.outlineVariant.withValues(alpha: 0.72),
                      width: 0.8,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: colors.background.withValues(
                          alpha: isDark ? 0.22 : 0.08,
                        ),
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
                              color: colors.surfaceVariant.withValues(
                                alpha: 0.72,
                              ),
                              border: Border.all(
                                color: colors.outlineVariant.withValues(
                                  alpha: 0.65,
                                ),
                                width: 0.7,
                              ),
                            ),
                            child: Icon(
                              Icons.add_rounded,
                              color: colors.onSurfaceVariant,
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
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 15,
                            color: colors.onSurface,
                            letterSpacing: -0.1,
                          ),
                          cursorColor: colors.primary,
                          decoration: InputDecoration(
                            hintText: 'Escribe un mensaje...',
                            hintStyle: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 15,
                              fontWeight: FontWeight.w400,
                              color: colors.onSurfaceVariant,
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
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 6,
                            ),
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
                        isDark: isDark,
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
