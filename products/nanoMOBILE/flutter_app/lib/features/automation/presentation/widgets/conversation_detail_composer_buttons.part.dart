part of 'conversation_detail_sheet.dart';

/// [ConversationDetailComposerButtons] — Botones auxiliares conectados al tema real del sistema (< 195 líneas).
extension ConversationDetailComposerButtons on _ConversationDetailSheetState {
  /// Botón oficial con el emblema de búho Nano AI para sugerencias inteligentes.
  Widget _buildOwlAiButton(AutomationVisualPalette visual) {
    final isDark = visual.isDark;
    final colors = visual.resolvedColors;

    return Semantics(
      key: const ValueKey('ai_suggest'),
      label: 'Sugerir con Nano IA',
      button: true,
      child: GestureDetector(
        onTap: _busy
            ? null
            : () {
                HapticFeedback.lightImpact();
                _generateAiSuggestion();
              },
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isDark
                ? colors.surfaceVariant.withValues(alpha: 0.60)
                : colors.surface.withValues(alpha: 0.90),
            border: Border.all(
              color: visual.accent.withValues(alpha: 0.40),
              width: 0.8,
            ),
            boxShadow: [
              BoxShadow(
                color: visual.accent.withValues(
                  alpha: isDark ? 0.28 : 0.16,
                ),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: _busy
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: visual.accent,
                    ),
                  )
                : ClipOval(
                    child: Image.asset(
                      'assets/nano/nano_owl.png',
                      width: 24,
                      height: 24,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.medium,
                      errorBuilder: (_, __, ___) => Icon(
                        CupertinoIcons.sparkles,
                        size: 18,
                        color: visual.accent,
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  /// Botón para grabar o enviar notas de voz con el micrófono del sistema.
  Widget _buildVoiceNoteButton(AutomationVisualPalette visual) {
    final colors = visual.resolvedColors;
    final isRec = _isRecordingVoiceNote;

    return Semantics(
      key: const ValueKey('voice_note_button'),
      label: isRec ? 'Enviar nota de voz' : 'Grabar nota de voz',
      button: true,
      child: GestureDetector(
        onTap: _busy ? null : _handleVoiceNoteTap,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isRec
                ? const Color(0xFFEF4444)
                : (visual.isDark
                    ? colors.surfaceVariant.withValues(alpha: 0.60)
                    : colors.surface.withValues(alpha: 0.90)),
            border: Border.all(
              color: isRec
                  ? Colors.white.withValues(alpha: 0.80)
                  : visual.accent.withValues(alpha: 0.40),
              width: 0.8,
            ),
            boxShadow: [
              BoxShadow(
                color: isRec
                    ? const Color(0xFFEF4444).withValues(alpha: 0.45)
                    : visual.accent.withValues(
                        alpha: visual.isDark ? 0.28 : 0.16,
                      ),
                blurRadius: isRec ? 12 : 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: Icon(
              isRec ? CupertinoIcons.arrow_up : CupertinoIcons.mic_fill,
              size: 18,
              color: isRec ? Colors.white : visual.accent,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIosComposerButton({
    Key? key,
    required IconData icon,
    required String tooltip,
    required Color color,
    required VoidCallback? onTap,
    double size = 36,
    double iconSize = 22,
  }) {
    return Semantics(
      key: key,
      label: tooltip,
      button: true,
      child: IconButton(
        padding: EdgeInsets.zero,
        constraints: BoxConstraints(minWidth: size, minHeight: size),
        icon: Icon(
          icon,
          size: iconSize,
          color: onTap == null ? color.withValues(alpha: 0.4) : color,
        ),
        onPressed: onTap,
      ),
    );
  }

  Widget _buildIosSendButton(AutomationVisualPalette visual) {
    final colors = visual.resolvedColors;
    return Semantics(
      key: const ValueKey('send_active'),
      label: 'Enviar',
      button: true,
      child: GestureDetector(
        onTap: _busy
            ? null
            : () {
                HapticFeedback.lightImpact();
                _sendReply();
              },
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [visual.accent, colors.primary],
            ),
            boxShadow: [
              BoxShadow(
                color: visual.accent.withValues(alpha: 0.35),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: _busy
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: visual.onAccent,
                    ),
                  )
                : Icon(
                    CupertinoIcons.arrow_up,
                    size: 19,
                    color: visual.onAccent,
                  ),
          ),
        ),
      ),
    );
  }
}
