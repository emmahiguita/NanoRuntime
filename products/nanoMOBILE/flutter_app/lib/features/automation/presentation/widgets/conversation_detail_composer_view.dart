part of 'conversation_detail_sheet.dart';

/// [ConversationDetailComposerView] — Barra de redacción estilo iOS Liquid Glass (< 120 líneas).
// QUÉ HACE: Renderiza la fila de redacción con botón (+), campo de texto esmerilado y botón animado de acción.
// CÓMO FUNCIONA: Usa AnimatedSwitcher para alternar con física de escala entre el botón de búho Nano IA y la flecha de envío.
// POR QUÉ: Divide la lógica de diseño para respetar el principio de responsabilidad única y límite < 200 líneas.
extension ConversationDetailComposerView on _ConversationDetailSheetState {
  Widget _buildComposerRow(
    AutomationVisualPalette visual, {
    required bool isLandscape,
  }) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: _inputController,
      builder: (context, value, _) => LayoutBuilder(
        builder: (context, constraints) {
          final hasText = value.text.trim().isNotEmpty;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Botón (+) iOS para adjuntos
              _buildIosComposerButton(
                icon: CupertinoIcons.plus_circle_fill,
                tooltip: 'Adjuntar',
                color: visual.textMuted,
                onTap: _busy ? null : _showAttachmentMenu,
                size: 36,
                iconSize: 26,
              ),
              const SizedBox(width: 6),
              // Campo de texto estilo cápsula esmerilada iMessage
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
              // Botón IA con emblema oficial de búho Nano o botón Enviar
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                transitionBuilder: (child, anim) =>
                    ScaleTransition(scale: anim, child: child),
                child: hasText
                    ? _buildIosSendButton(visual)
                    : _buildOwlAiButton(visual),
              ),
            ],
          );
        },
      ),
    );
  }
}
