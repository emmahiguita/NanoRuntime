import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
export 'nano_assistant_header.dart';

/// Editor único del flotante. La acción se habilita con texto, salvo lectura de
/// pantalla. Detener ocupa su mismo lugar; no se duplican acciones inferiores.
class NanoAssistantComposer extends StatelessWidget {
  const NanoAssistantComposer({
    super.key,
    required this.input,
    required this.isListening,
    required this.audioLevel,
    required this.onVoice,
    required this.onSend,
    required this.onCancel,
    this.onAdd,
    this.hintText,
    this.compact = false,
    this.busy = false,
    this.screenReaderMode = false,
    this.actionLabel = 'Ejecutar',
  });
  final TextEditingController input;
  final bool isListening, compact, busy, screenReaderMode;
  final ValueListenable<double> audioLevel;
  final VoidCallback? onVoice;
  final VoidCallback onSend, onCancel;
  final ValueChanged<BuildContext>? onAdd;
  final String? hintText;
  final String actionLabel;

  /// Usa la paleta compartida y un fondo ligero, sin otro filtro de desenfoque.
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: .35),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: .55)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 4, 5, 4),
        child: Row(
          children: [
            if (onAdd != null && !screenReaderMode)
              Builder(
                builder: (anchor) => IconButton(
                  tooltip: 'Adjuntos y complementos',
                  onPressed: busy || isListening ? null : () => onAdd!(anchor),
                  icon: const Icon(Icons.add_rounded, size: 22),
                ),
              ),
            Expanded(
              child: screenReaderMode
                  ? Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'Texto accesible de la app activa',
                        style: TextStyle(color: colors.onSurfaceVariant),
                      ),
                    )
                  : TextField(
                      controller: input,
                      readOnly: busy || isListening,
                      minLines: 1,
                      maxLines: compact ? 2 : 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: busy || isListening ? null : (_) => onSend(),
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: colors.onSurface),
                      decoration: InputDecoration(
                        hintText: hintText ?? 'Escribe una instrucción…',
                        hintMaxLines: 2,
                        hintStyle: TextStyle(color: colors.onSurfaceVariant),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        filled: false,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                    ),
            ),
            if (onVoice != null && !screenReaderMode)
              IconButton(
                tooltip: isListening ? 'Detener dictado' : 'Dictar por voz',
                onPressed: busy ? null : onVoice,
                icon: Icon(
                  isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
                  size: 22,
                  color: colors.onSurfaceVariant,
                ),
              ),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: input,
              builder: (context, value, _) => IconButton.filled(
                tooltip: busy ? 'Solicitar detención' : actionLabel,
                onPressed: isListening
                    ? null
                    : busy
                    ? onCancel
                    : screenReaderMode || value.text.trim().isNotEmpty
                    ? onSend
                    : null,
                style: IconButton.styleFrom(
                  minimumSize: const Size(48, 48),
                  backgroundColor: colors.primary,
                  foregroundColor: colors.onPrimary,
                ),
                icon: Icon(
                  busy ? Icons.stop_rounded : Icons.arrow_upward_rounded,
                  size: 22,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
