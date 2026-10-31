part of 'conversation_detail_sheet.dart';

/// [ConversationDetailComposerView] — Barra de redacción estilo iOS Liquid Glass (< 160 líneas).
// QUÉ HACE: Renderiza la fila de redacción con botón (+), campo de texto esmerilado, nota de voz en vivo y envío.
// CÓMO FUNCIONA: Conmuta entre el campo de texto y la barra de grabación activa con temporizador y descarte.
// POR QUÉ: Divide la lógica de diseño para respetar el principio de responsabilidad única y límite < 200 líneas.
extension ConversationDetailComposerView on _ConversationDetailSheetState {
  Widget _buildComposerRow(
    AutomationVisualPalette visual, {
    required bool isLandscape,
  }) {
    if (_isRecordingVoiceNote) {
      return _buildVoiceRecordingRow(visual);
    }

    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: _inputController,
      builder: (context, value, _) => LayoutBuilder(
        builder: (context, constraints) {
          final hasText = value.text.trim().isNotEmpty;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _buildIosComposerButton(
                icon: CupertinoIcons.plus_circle_fill,
                tooltip: 'Adjuntar',
                color: visual.textMuted,
                onTap: _busy ? null : _showAttachmentMenu,
                size: 36,
                iconSize: 26,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Container(
                  constraints: const BoxConstraints(minHeight: 36),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: visual.isDark
                        ? visual.cardStart.withValues(alpha: 0.35)
                        : visual.inputFill.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: visual.line,
                      width: 0.8,
                    ),
                  ),
                  child: TextField(
                    controller: _inputController,
                    enabled: !_busy,
                    minLines: 1,
                    maxLines: isLandscape ? 2 : 4,
                    keyboardType: TextInputType.multiline,
                    textCapitalization: TextCapitalization.sentences,
                    cursorColor: visual.accent,
                    style: TextStyle(
                      color: visual.text,
                      fontFamily: 'Inter',
                      fontFamilyFallback: ConversationDetailSheet._sfFallback,
                      fontSize: 14.5,
                      height: 1.3,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Mensaje',
                      hintStyle: TextStyle(
                        color: visual.textMuted.withValues(alpha: 0.70),
                        fontFamily: 'Inter',
                        fontFamilyFallback: ConversationDetailSheet._sfFallback,
                        fontSize: 14.5,
                      ),
                      filled: false,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                transitionBuilder: (child, anim) =>
                    ScaleTransition(scale: anim, child: child),
                child: hasText
                    ? _buildIosSendButton(visual)
                    : Row(
                        key: const ValueKey('composer_idle_actions'),
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildOwlAiButton(visual),
                          const SizedBox(width: 6),
                          _buildVoiceNoteButton(visual),
                        ],
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Barra de grabación activa con contador de tiempo y opción de cancelar.
  Widget _buildVoiceRecordingRow(AutomationVisualPalette visual) {
    final min = (_recordingSeconds ~/ 60).toString();
    final sec = (_recordingSeconds % 60).toString().padLeft(2, '0');

    return Row(
      children: [
        IconButton(
          tooltip: 'Descartar nota de voz',
          icon: const Icon(CupertinoIcons.trash, color: Color(0xFFEF4444), size: 22),
          onPressed: _busy ? null : _cancelRecordingVoiceNote,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444).withValues(alpha: visual.isDark ? 0.16 : 0.10),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFFEF4444).withValues(alpha: 0.40),
                width: 0.8,
              ),
            ),
            child: Row(
              children: [
                const Icon(CupertinoIcons.circle_fill, color: Color(0xFFEF4444), size: 10),
                const SizedBox(width: 8),
                Text(
                  '$min:$sec',
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFEF4444),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Grabando nota de voz...',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      color: visual.textMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 6),
        _buildVoiceNoteButton(visual),
      ],
    );
  }
}
