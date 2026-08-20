import 'package:flutter/material.dart';
import 'package:nanoai/core/theme/design_tokens.dart';
import 'package:nanoai/core/theme/nano_motion.dart';
import 'package:nanoai/core/theme/nano_type.dart';

/// Opción de un [ChoiceGroup] (value + label + icon).
class ChoiceOption {
  final String value;
  final String label;
  final IconData icon;

  const ChoiceOption(this.value, this.label, this.icon);
}

/// Grupo de elección tipo ChoiceChip. Compartido por Settings (tema de
/// interfaz) y Automation (nivel de automatización) — una sola
/// implementación, cero duplicados.
class ChoiceGroup extends StatelessWidget {
  const ChoiceGroup({
    super.key,
    required this.label,
    required this.description,
    required this.options,
    required this.selectedValue,
    required this.onSelected,
    required this.colors,
  });

  final String label;
  final String description;
  final List<ChoiceOption> options;
  final String selectedValue;
  final ValueChanged<String> onSelected;
  final NanoColors colors;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: NanoType.body(colors.onSurface)),
      const SizedBox(height: NanoSpacing.xs),
      AnimatedSize(
        duration: NanoMotion.adapt(context, NanoMotionDurations.standard),
        curve: NanoMotionCurves.emphasized,
        alignment: Alignment.topLeft,
        child: Text(
          description,
          key: ValueKey(description),
          style: NanoType.caption(colors.onSurfaceVariant),
        ),
      ),
      const SizedBox(height: NanoSpacing.md),
      Wrap(
        spacing: NanoSpacing.sm,
        runSpacing: NanoSpacing.sm,
        children: [
          for (final option in options)
            ChoiceChip(
              avatar: Icon(
                option.icon,
                size: 17,
                color: selectedValue == option.value
                    ? colors.primary
                    : colors.onSurfaceVariant,
              ),
              label: Text(option.label),
              labelStyle: NanoType.caption(
                selectedValue == option.value
                    ? colors.primary
                    : colors.onSurface,
              ),
              selected: selectedValue == option.value,
              onSelected: (_) => onSelected(option.value),
              selectedColor: colors.primaryContainer,
              backgroundColor: colors.surface.withValues(alpha: 0.52),
              side: BorderSide(
                color: selectedValue == option.value
                    ? colors.primary.withValues(alpha: 0.28)
                    : colors.outlineVariant.withValues(alpha: 0.55),
              ),
              shape: const RoundedRectangleBorder(
                borderRadius: NanoShapes.full,
              ),
              showCheckmark: false,
            ),
        ],
      ),
    ],
  );
}
