part of 'chat_screen.dart';

// chat_screen_composer.part.dart — Barra de redacción Liquid Glass Dock.
// QUÉ HACE: Aloja el compositor inferior flotante con botón (+), campo de texto, dictado y envío.
// CÓMO FUNCIONA: Usa GlassSurface como motor óptico auténtico, adaptándose a pantalla y teclado.
// POR QUÉ: Sustituye contenedores opacos manuales por cristal líquido soberano iOS (< 160 líneas).

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
        // Tira de archivos adjuntos en pastillas flotantes
        if (state.attachments.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: _AttachmentPillsStrip(
              attachments: state.attachments,
              onRemove: notifier.removeAttachment,
            ),
          ),

        // iOS Liquid Glass Dock
        SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              compact ? 8 : 12,
              2,
              compact ? 8 : 12,
              compact ? 6 : 8,
            ),
            child: GlassSurface(
              radius: 26,
              blur: 24,
              opacity: isDark ? 0.72 : 0.88,
              borderWidth: 0.8,
              interactive: false,
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 6 : 8,
                vertical: compact ? 3 : 4,
              ),
              child: SizedBox(
                height: compact ? 38 : 42,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // 1. Botón (+) Circular Liquid Glass con CupertinoIcons.plus
                    Semantics(
                      label: 'Adjuntos y herramientas',
                      button: true,
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(999),
                          onTap: state.generating
                              ? null
                              : () {
                                  HapticFeedback.selectionClick();
                                  _attachFile();
                                },
                          child: Container(
                            width: compact ? 30 : 34,
                            height: compact ? 30 : 34,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: colors.surfaceVariant.withValues(
                                alpha: isDark ? 0.45 : 0.65,
                              ),
                              border: Border.all(
                                color: colors.outlineVariant.withValues(
                                  alpha: isDark ? 0.35 : 0.25,
                                ),
                                width: 0.7,
                              ),
                            ),
                            child: Center(
                              child: Icon(
                                CupertinoIcons.plus,
                                color: colors.onSurface,
                                size: compact ? 16 : 18,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // 2. Campo de texto limpio y fluido
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
                            color: colors.onSurfaceVariant.withValues(
                              alpha: 0.75,
                            ),
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
                            vertical: 8,
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
                    const SizedBox(width: 4),

                    // 3. Botón Micrófono
                    _buildComposerMicButton(compact: compact, colors: colors),
                    const SizedBox(width: 4),

                    // 4. Botón Enviar Compacto
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
      ],
    );
  }
}