part of 'chat_screen.dart';

// chat_screen_composer_controls.part.dart — Controles interactivos del dock de composición.
// QUÉ HACE: Renderiza los botones de micrófono y envío/detención con hápticos y semántica iOS.
// CÓMO FUNCIONA: Cambia dinámicamente de icono y estado según generación, dictado y presencia de texto.
// POR QUÉ: Extrae los botones del cuerpo principal respetando SOLID y la cota de < 130 líneas.

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
              _listening
                  ? CupertinoIcons.stop_circle_fill
                  : CupertinoIcons.mic_fill,
              color: _listening
                  ? const Color(0xFFEF4444)
                  : colors.onSurfaceVariant.withValues(alpha: 0.75),
              size: compact ? 16 : 18,
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
            onTap: () {
              HapticFeedback.lightImpact();
              onStop();
            },
            child: SizedBox(
              width: size,
              height: size,
              child: const Center(
                child: Icon(
                  CupertinoIcons.stop_fill,
                  color: Colors.white,
                  size: 15,
                ),
              ),
            ),
          ),
        ),
      );
    }

    final activeColor = colors.primary;

    return Semantics(
      label: 'Enviar mensaje',
      button: true,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: hasText
              ? activeColor
              : colors.surfaceVariant.withValues(alpha: 0.72),
          boxShadow: [
            if (hasText)
              BoxShadow(
                color: activeColor.withValues(alpha: 0.35),
                blurRadius: 10,
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
                CupertinoIcons.arrow_up,
                color: hasText ? Colors.white : colors.onSurfaceVariant,
                size: compact ? 16 : 18,
              ),
            ),
          ),
        ),
      ),
    );
  }
}