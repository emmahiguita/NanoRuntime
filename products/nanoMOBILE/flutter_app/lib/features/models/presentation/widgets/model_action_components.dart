// model_action_components.dart — Componentes atómicos de estilo iOS para el catálogo de modelos.
// QUÉ HACE: Provee botones hápticos de acción, píldoras de segmentación, tags y encabezados de sección.
// CÓMO FUNCIONA: Widgets sin estado desacoplados con NanoThemeExtension y micro-interacciones.
// POR QUÉ: Estandariza la estética en tarjetas de modelos cumpliendo la regla de modularidad (<200 líneas).
import 'package:flutter/material.dart';
import '../../../../core/theme/design_tokens.dart';
export 'model_filter_pill.dart';
export 'model_section_header.dart';

class IosActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final Color? color;
  final bool filled;

  const IosActionButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.color,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;
    final effectiveColor = color ?? colors.primary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(NanoRadius.small),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: filled
                ? effectiveColor
                : effectiveColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(NanoRadius.small),
            border: filled
                ? null
                : Border.all(
                    color: effectiveColor.withValues(alpha: 0.25),
                    width: 0.8,
                  ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 13,
                color: filled ? colors.surface : effectiveColor,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: filled ? colors.surface : effectiveColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class IosTag extends StatelessWidget {
  final String label;
  final Color? color;

  const IosTag({super.key, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;
    final effectiveColor = color ?? colors.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: effectiveColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
          color: effectiveColor,
        ),
      ),
    );
  }
}

class IosSpecText extends StatelessWidget {
  final String label, value;
  final Color? color;

  const IosSpecText({
    super.key,
    required this.label,
    required this.value,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label ',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 10.5,
            color: colors.onSurfaceVariant,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            color: color ?? colors.onSurface,
          ),
        ),
      ],
    );
  }
}

class IosDotSeparator extends StatelessWidget {
  const IosDotSeparator({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        '•',
        style: TextStyle(
          color: colors.onSurfaceVariant.withValues(alpha: 0.5),
          fontSize: 9,
        ),
      ),
    );
  }
}
