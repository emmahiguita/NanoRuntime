part of 'chat_screen.dart';

extension _ChatScreenComposerControls on _ChatScreenState {
  Widget _buildComposerMicButton({
    required bool compact,
    required NanoColors colors,
  }) {
    return Semantics(
      label: _listening ? 'Detener dictado por voz' : 'Dictar por voz',
      button: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: _toggleMic,
          child: Container(
            width: compact ? 30 : 34,
            height: compact ? 30 : 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _listening
                  ? const Color(0xFFEF4444).withValues(alpha: 0.20)
                  : Colors.transparent,
            ),
            child: Icon(
              _listening ? Icons.stop_circle_rounded : Icons.mic_none_rounded,
              color: _listening ? const Color(0xFFEF4444) : const Color(0xFFA3B8CC),
              size: compact ? 17 : 19,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildComposerSendButton({
    required bool isGenerating,
    required bool hasText,
    required bool compact,
    required bool isDark,
    required NanoColors colors,
    required VoidCallback onStop,
    required void Function(String text) onSend,
  }) {
    final size = compact ? 30.0 : 34.0;

    if (isGenerating) {
      return Semantics(
        label: 'Detener generación en curso',
        button: true,
        child: Material(
          color: const Color(0xFFEF4444),
          shape: const CircleBorder(),
          child: InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: onStop,
            child: SizedBox(
              width: size,
              height: size,
              child: const Icon(Icons.stop_rounded, color: Colors.white, size: 18),
            ),
          ),
        ),
      );
    }

    return Semantics(
      label: 'Enviar mensaje',
      button: true,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: hasText
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF4DD7FF), // Bright Cyan
                    Color(0xFF1475F5), // Accent Blue
                  ],
                )
              : null,
          color: hasText ? null : Colors.white.withValues(alpha: 0.08),
          boxShadow: [
            if (hasText)
              BoxShadow(
                color: const Color(0xFF0099FF).withValues(alpha: 0.35),
                blurRadius: 12,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          child: InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: hasText
                ? () {
                    HapticFeedback.mediumImpact();
                    final text = _textController.text.trim();
                    onSend(text);
                    _textController.clear();
                    setState(() => _dictatedText = '');
                  }
                : null,
            child: Center(
              child: Icon(
                Icons.send_rounded,
                color: hasText ? Colors.white : const Color(0xFF5E758C),
                size: compact ? 15 : 17,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
