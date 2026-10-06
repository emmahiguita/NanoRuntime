// QUÉ: entrada legible con enviar, voz y cancelación reales.
// CÓMO: una sola superficie Material y botones semánticos de 48 píxeles.
// POR QUÉ: elimina el relleno ovalado duplicado y controles difíciles de pulsar.
library;

import 'package:flutter/material.dart';

class NanoNavSearchInputRow extends StatelessWidget {
  const NanoNavSearchInputRow({
    super.key,
    required this.brightness,
    required this.controller,
    required this.focusNode,
    required this.hint,
    required this.hasText,
    required this.onAttach,
    required this.onSubmitted,
    required this.onClear,
    required this.onVoice,
    required this.listening,
    required this.compact,
    this.transparent = false,
    this.processing = false,
    this.onStop,
  });
  final Brightness brightness;
  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;
  final bool hasText, listening, compact, transparent, processing;
  final VoidCallback? onAttach, onVoice, onStop;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback onClear;

  /// El indicador ocupado no simula progreso ni borra una orden sin aceptarla.
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Material(
      color: colors.surfaceContainerHighest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: theme.brightness == Brightness.dark
              ? Colors.transparent
              : colors.outlineVariant,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              onSubmitted: processing ? null : onSubmitted,
              textInputAction: TextInputAction.send,
              minLines: 1,
              maxLines: compact ? 2 : 5,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurface,
              ),
              cursorColor: colors.primary,
              decoration: InputDecoration(
                hintText: hint,
                hintMaxLines: 1,
                isDense: true,
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 14,
                ),
                hintStyle: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
          ),
          // Adjuntar y borrar comparten el espacio, evitando cuatro botones juntos.
          if (!hasText && onAttach != null)
            _action(context, Icons.add_rounded, 'Opciones de entrada', onAttach)
          else if (hasText)
            _action(context, Icons.clear_rounded, 'Borrar texto', onClear),
          if (processing)
            _action(context, Icons.stop_rounded, 'Detener ejecución', onStop)
          else if (hasText)
            _action(
              context,
              Icons.arrow_upward_rounded,
              'Enviar',
              onSubmitted == null ? null : () => onSubmitted!(controller.text),
            )
          else
            _action(
              context,
              listening ? Icons.stop_rounded : Icons.mic_rounded,
              listening ? 'Detener voz' : 'Dictar por voz',
              onVoice,
            ),
        ],
      ),
    );
  }

  /// Semantics no depende de Tooltip; las acciones nulas quedan deshabilitadas.
  Widget _action(
    BuildContext context,
    IconData icon,
    String label,
    VoidCallback? action,
  ) => Semantics(
    button: true,
    label: label,
    child: IconButton(
      onPressed: action,
      icon: Icon(icon, size: 20),
      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      color: Theme.of(context).colorScheme.primary,
    ),
  );
}
