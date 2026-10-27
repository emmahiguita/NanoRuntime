// QUÉ: entrada Liquid Glass con enviar, voz y cancelación reales.
// CÓMO: una superficie translúcida y botones semánticos de 48 píxeles.
// POR QUÉ: integra la escritura al dock iOS sin alterar callbacks ni foco.
library;

import 'package:flutter/material.dart';
import 'nano_input_tool_controls.dart';

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
    this.submitLabel = 'Enviar',
    this.toolControls,
  });

  final Brightness brightness;
  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;
  final String submitLabel;
  final NanoInputToolControls? toolControls;
  final bool hasText;
  final bool listening;
  final bool compact;
  final bool transparent;
  final bool processing;
  final VoidCallback? onAttach;
  final VoidCallback? onVoice;
  final VoidCallback? onStop;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    // La carcasa del dock ya filtra el fondo. Una segunda lente aquí
    // duplicaba el desenfoque y lavaba el texto, especialmente en gris.
    return Material(
      color: colors.surface.withValues(alpha: transparent ? .10 : .20),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colors.outlineVariant),
      ),
      child: Row(
        children: [
          // El + permanece separado del componente activo en todos los estados.
          if (onAttach != null && (!hasText || toolControls != null))
            Builder(
              builder: (anchor) => _action(
                anchor,
                Icons.add_rounded,
                'Adjuntos y complementos',
                processing
                    ? null
                    : toolControls != null
                    ? () => (toolControls!.onAdd ?? toolControls!.onOptions)(
                        anchor,
                      )
                    : onAttach,
              ),
            ),
          if (toolControls case final tools? when tools.selected)
            NanoInputToolButton(controls: tools, enabled: !processing),
          Expanded(
            child: TextField(
              controller: controller,
              autofocus: toolControls != null,
              readOnly: processing,
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
          if (hasText &&
              toolControls == null &&
              MediaQuery.sizeOf(context).width >= 340)
            _action(context, Icons.clear_rounded, 'Borrar texto', onClear),
          if (processing)
            _action(context, Icons.stop_rounded, 'Detener ejecución', onStop)
          else if (hasText)
            _action(
              context,
              Icons.arrow_upward_rounded,
              submitLabel,
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
