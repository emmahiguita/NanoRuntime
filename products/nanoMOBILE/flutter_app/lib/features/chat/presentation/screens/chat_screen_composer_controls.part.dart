part of 'chat_screen.dart';

// QUÉ HACE:
// Controles de acción interactivos para la barra de redacción: micrófono y botón de envío/detención.
//
// CÓMO FUNCIONA:
// - Micrófono: detecta escucha activa pulsando en color rojo; en reposo ofrece acceso al reconocedor nativo.
// - Botón de envío: en generación muestra icono de parada; con texto escrito se ilumina con acento y sombra cristal;
//   cuando está vacío se atenúa sutilmente sin bloquear el layout.
//
// POR QUÉ:
// Aplica Clean Architecture (SRP), aislando los botones de control de la disposición del campo de texto
// para mantener los archivos estrictamente por debajo de las 200 líneas de código.
extension _ChatScreenComposerControls on _ChatScreenState {
  /// QUÉ HACE: Construye el botón interactivo de dictado por voz.
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
          borderRadius: BorderRadius.circular(20),
          onTap: _toggleMic,
          child: Container(
            width: compact ? 34 : 38,
            height: compact ? 34 : 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _listening
                  ? const Color(0xFFEF4444).withValues(alpha: 0.15)
                  : Colors.transparent,
            ),
            child: Icon(
              _listening ? Icons.stop_circle_rounded : Icons.mic_none_rounded,
              color: _listening
                  ? const Color(0xFFEF4444)
                  : (colors is NanoDarkColors
                      ? colors.onSurface.withValues(alpha: 0.70)
                      : const Color(0xFF64748B)),
              size: compact ? 19 : 21,
            ),
          ),
        ),
      ),
    );
  }

  /// QUÉ HACE: Construye el botón de envío o detención de generación según el estado.
  Widget _buildComposerSendButton({
    required bool isGenerating,
    required bool hasText,
    required bool compact,
    required bool isDark,
    required NanoColors colors,
    required VoidCallback onStop,
    required void Function(String text) onSend,
  }) {
    if (isGenerating) {
      return Semantics(
        label: 'Detener generación en curso',
        button: true,
        child: Material(
          color: const Color(0xFFEF4444),
          shape: const CircleBorder(),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: onStop,
            child: SizedBox(
              width: compact ? 34 : 38,
              height: compact ? 34 : 38,
              child: const Icon(
                Icons.stop_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ),
      );
    }

    return Semantics(
      label: 'Enviar mensaje',
      button: true,
      child: Material(
        color: hasText
            ? colors.accent
            : (isDark ? const Color(0x1AFFFFFF) : const Color(0xFFF1F5F9)),
        shape: const CircleBorder(),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: hasText
              ? () {
                  final text = _textController.text.trim();
                  onSend(text);
                  _textController.clear();
                  setState(() => _dictatedText = '');
                }
              : null,
          child: SizedBox(
            width: compact ? 34 : 38,
            height: compact ? 34 : 38,
            child: Icon(
              Icons.arrow_upward_rounded,
              color: hasText
                  ? Colors.white
                  : (isDark
                      ? colors.onSurface.withValues(alpha: 0.30)
                      : const Color(0xFF94A3B8)),
              size: compact ? 18 : 20,
            ),
          ),
        ),
      ),
    );
  }
}
