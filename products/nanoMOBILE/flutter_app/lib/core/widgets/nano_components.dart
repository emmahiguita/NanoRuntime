import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';
import '../theme/nano_type.dart';
import 'nano_optical_surface.dart';

export 'nano_optical_surface.dart';

/// ── Componentes de tema compartidos ──
///
/// Cada componente inyecta TIPOGRAFÍA (NanoType) y COLORES (NanoColors)
/// desde el tema activo: una pantalla que los usa queda automáticamente
/// correcta en modo claro y oscuro, sin TextStyle crudos ni hex sueltos.

/// Tarjeta de superficie con glassmorphism óptico y bisel metálico perimetral.
class NanoCard extends StatelessWidget {
  const NanoCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(NanoSpacing.md),
    this.margin,
    this.onTap,
    this.highlight = false,
    this.borderRadius = NanoRadius.large,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final bool highlight;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return NanoOpticalSurface(
      borderRadius: borderRadius,
      margin: margin,
      padding: padding,
      isActive: highlight,
      onTap: onTap,
      child: child,
    );
  }
}

/// Encabezado de sección: icono dentro de un contenedor tintado + título
/// (NanoType.title) + subtítulo opcional (NanoType.caption).
class NanoSectionHeader extends StatelessWidget {
  const NanoSectionHeader(
    this.title,
    this.icon, {
    super.key,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final IconData icon;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;

    return Padding(
      padding: const EdgeInsets.only(bottom: NanoSpacing.sm),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.12),
              borderRadius: NanoShapes.small,
            ),
            child: Icon(icon, size: NanoIcons.medium, color: colors.primary),
          ),
          const SizedBox(width: NanoSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: NanoType.title(colors.onSurface)),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: NanoType.caption(colors.onSurfaceVariant),
                  ),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Píldora de estado con semántica de color (no hex sueltos).
/// `kind` mapea a los tokens: success/warning/danger/info/accent/neutral.
class NanoBadge extends StatelessWidget {
  const NanoBadge(
    this.label, {
    super.key,
    this.kind = BadgeKind.neutral,
    this.dot = true,
  });

  final String label;
  final BadgeKind kind;
  final bool dot;

  @override
  Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;
    final tint = switch (kind) {
      BadgeKind.success => colors.success,
      BadgeKind.warning => colors.warning,
      BadgeKind.danger => colors.danger,
      BadgeKind.info => colors.info,
      BadgeKind.accent => colors.accent,
      BadgeKind.neutral => colors.onSurfaceVariant,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.12),
        borderRadius: NanoShapes.full,
        border: Border.all(color: tint.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
            ),
            const SizedBox(width: 5),
          ],
          Text(label, style: NanoType.overline(tint)),
        ],
      ),
    );
  }
}

enum BadgeKind { success, warning, danger, info, accent, neutral }

/// Número de métrica grande (RAM, temperatura, batería, etc.) con
/// NanoType.metric y unidad opcional en caption.
class NanoMetricText extends StatelessWidget {
  const NanoMetricText(
    this.value, {
    super.key,
    this.unit,
    this.color,
  });

  final String value;
  final String? unit;
  /// Tinte opcional del número; por defecto onSurface.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          value,
          style: NanoType.metric(color ?? colors.onSurface),
        ),
        if (unit != null) ...[
          const SizedBox(width: 3),
          Text(
            unit!,
            style: NanoType.caption(colors.onSurfaceVariant),
          ),
        ],
      ],
    );
  }
}

/// Botón de acción estandarizado: primario (relleno) u outline, con icono
/// opcional y texto siempre en NanoType.label. Los colores de fondo/texto
/// siguen la convención del theme (negro sobre verde neón en oscuro,
/// blanco sobre esmeralda en claro).
class NanoActionButton extends StatelessWidget {
  const NanoActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.primary = true,
    this.expanded = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool primary;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;
    final labelStyle = primary
        ? NanoType.label(
            colors is NanoDarkColors ? const Color(0xFF000000) : Colors.white)
        : NanoType.label(colors.primary);

    final button = primary
        ? ElevatedButton.icon(
            onPressed: onPressed,
            icon: icon != null ? Icon(icon, size: NanoIcons.small) : null,
            label: Text(label, style: labelStyle),
          )
        : OutlinedButton.icon(
            onPressed: onPressed,
            icon: icon != null ? Icon(icon, size: NanoIcons.small) : null,
            label: Text(label, style: labelStyle),
          );

    return expanded ? SizedBox(width: double.infinity, child: button) : button;
  }
}
