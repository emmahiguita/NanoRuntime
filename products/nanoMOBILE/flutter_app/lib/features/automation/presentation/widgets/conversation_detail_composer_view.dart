part of 'conversation_detail_sheet.dart';

/// Compositor Material 3 compacto para escritura, adjuntos y envío real.
extension ConversationDetailComposerView on _ConversationDetailSheetState {
  Widget _buildComposerRow(
    AutomationVisualPalette visual, {
    required bool isLandscape,
  }) {
    return Row(
      children: [
        if (isLandscape) ...[
          IconButton(
            tooltip: 'Sugerir con IA',
            onPressed: _busy ? null : _generateAiSuggestion,
            icon: const Icon(CupertinoIcons.sparkles, size: 17),
            color: const Color(0xFF007AFF),
            visualDensity: VisualDensity.compact,
          ),
          const SizedBox(width: 4),
        ],
        IconButton.filledTonal(
          tooltip: 'Adjuntar documento, imagen, PDF o formulario',
          onPressed: _busy ? null : _showAttachmentMenu,
          icon: Icon(CupertinoIcons.paperclip, size: isLandscape ? 18 : 20),
          style: IconButton.styleFrom(
            foregroundColor: visual.accent,
            backgroundColor: visual.accent.withValues(alpha: 0.12),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: _buildReplyField(visual, isLandscape: isLandscape)),
        const SizedBox(width: 8),
        IconButton.filled(
          tooltip: 'Enviar respuesta',
          onPressed: _busy ? null : _sendReply,
          style: IconButton.styleFrom(
            fixedSize: Size.square(isLandscape ? 36 : 40),
            backgroundColor: const Color(0xFF007AFF),
            foregroundColor: Colors.white,
            disabledBackgroundColor: const Color(
              0xFF007AFF,
            ).withValues(alpha: 0.45),
          ),
          icon: _busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Icon(CupertinoIcons.arrow_up, size: isLandscape ? 17 : 19),
        ),
      ],
    );
  }

  Widget _buildReplyField(
    AutomationVisualPalette visual, {
    required bool isLandscape,
  }) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide(
        color: Colors.white.withValues(alpha: visual.isDark ? 0.18 : 0.50),
      ),
    );
    return TextField(
      controller: _inputController,
      enabled: !_busy,
      maxLines: isLandscape ? 2 : 3,
      minLines: 1,
      style: TextStyle(color: visual.text, fontFamily: 'Inter', fontSize: 14),
      decoration: InputDecoration(
        hintText: 'Escribe tu respuesta...',
        hintStyle: TextStyle(
          color: visual.textMuted,
          fontFamily: 'Inter',
          fontSize: 13.5,
        ),
        filled: true,
        fillColor: Colors.white.withValues(alpha: visual.isDark ? 0.08 : 0.85),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        enabledBorder: border,
        focusedBorder: border.copyWith(
          borderSide: const BorderSide(color: Color(0xFF007AFF), width: 1.5),
        ),
      ),
    );
  }
}
