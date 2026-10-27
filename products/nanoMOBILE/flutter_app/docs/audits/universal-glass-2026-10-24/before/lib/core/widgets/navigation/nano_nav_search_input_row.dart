// QUÉ: entrada Liquid Glass con enviar, voz y cancelación reales.
// CÓMO: una superficie translúcida y botones semánticos de 48 píxeles.
// POR QUÉ: integra la escritura al dock iOS sin alterar callbacks ni foco.
library;

import 'dart:ui';

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
    final dark = theme.brightness == Brightness.dark;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Material(
          color: dark
              ? const Color(0xFF111827).withValues(alpha: 0.58)
              : Colors.white.withValues(alpha: 0.52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: dark
                  ? Colors.white.withValues(alpha: 0.13)
                  : Colors.white.withValues(alpha: 0.62),
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
              if (!hasText && onAttach != null)
                _action(
                  context,
                  Icons.add_rounded,
                  'Opciones de entrada',
                  onAttach,
                )
              else if (hasText)
                _action(context, Icons.clear_rounded, 'Borrar texto', onClear),
              if (processing)
                _action(
                  context,
                  Icons.stop_rounded,
                  'Detener ejecución',
                  onStop,
                )
              else if (hasText)
                _action(
                  context,
                  Icons.arrow_upward_rounded,
                  'Enviar',
                  onSubmitted == null
                      ? null
                      : () => onSubmitted!(controller.text),
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
        ),
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
