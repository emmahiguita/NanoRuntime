// model_action_components.dart — Componentes atómicos de estilo iOS para el catálogo de modelos.
// QUÉ HACE: Provee botones hápticos de acción, píldoras de segmentación, tags y encabezados de sección.
// CÓMO FUNCIONA: Widgets sin estado desacoplados con NanoThemeExtension y micro-interacciones.
// POR QUÉ: Estandariza la estética en tarjetas de modelos cumpliendo la regla de modularidad (<200 líneas).
import 'package:flutter/material.dart';
import '../../../../core/theme/design_tokens.dart';

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
            color: filled ? effectiveColor : effectiveColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(NanoRadius.small),
            border: filled ? null : Border.all(color: effectiveColor.withValues(alpha: 0.25), width: 0.8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13, color: filled ? colors.surface : effectiveColor),
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

class IosSegmentPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const IosSegmentPill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? colors.primary.withValues(alpha: 0.18) : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? colors.primary : colors.outlineVariant.withValues(alpha: 0.3),
            width: selected ? 1.2 : 0.8,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 11.5,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? colors.primary : colors.onSurfaceVariant,
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
        style: TextStyle(fontFamily: 'Inter', fontSize: 9.5, fontWeight: FontWeight.w700, color: effectiveColor),
      ),
    );
  }
}

class IosSpecText extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const IosSpecText({super.key, required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$label ', style: TextStyle(fontFamily: 'Inter', fontSize: 10.5, color: colors.onSurfaceVariant)),
        Text(value, style: TextStyle(fontFamily: 'Inter', fontSize: 10.5, fontWeight: FontWeight.w600, color: color ?? colors.onSurface)),
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
      child: Text('•', style: TextStyle(color: colors.onSurfaceVariant.withValues(alpha: 0.5), fontSize: 9)),
    );
  }
}

class IosSectionHeader extends StatelessWidget {
  final String title;
  final int count;

  const IosSectionHeader({super.key, required this.title, required this.count});

  @override
  Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;
    return Padding(
      padding: const EdgeInsets.only(left: 4, top: 12, bottom: 6),
      child: Row(
        children: [
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: colors.onSurfaceVariant.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: colors.surfaceVariant.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: TextStyle(fontFamily: 'Inter', fontSize: 10, fontWeight: FontWeight.w700, color: colors.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}
