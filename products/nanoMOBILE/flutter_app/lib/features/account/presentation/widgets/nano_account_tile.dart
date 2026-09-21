import 'package:flutter/material.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/theme/nano_type.dart';
import '../../../../core/widgets/nano_optical_surface.dart';

/// QUÉ HACE:
/// Celda de ajuste o navegación para el centro de cuenta Nano.
///
/// CÓMO FUNCIONA:
/// Provee una fila interactiva con icono tintado, título, descripción y trailing
/// personalizable (o flecha chevron de avance).
///
/// POR QUÉ:
/// Estandariza la jerarquía de opciones en el Centro de Cuenta y las secciones de configuración.
class NanoAccountTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool isDanger;

  const NanoAccountTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.isDanger = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;
    final itemColor = isDanger ? colors.error : colors.onSurface;
    final iconBg = isDanger
        ? colors.error.withValues(alpha: 0.12)
        : colors.primary.withValues(alpha: 0.12);
    final iconColor = isDanger ? colors.error : colors.primary;

    return NanoOpticalSurface(
      borderRadius: NanoRadius.medium,
      margin: const EdgeInsets.only(bottom: NanoSpacing.sm),
      padding: const EdgeInsets.symmetric(
        horizontal: NanoSpacing.md,
        vertical: NanoSpacing.sm + 2,
      ),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(NanoRadius.small),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: NanoSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: NanoType.title(itemColor)),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!, style: NanoType.caption(colors.onSurfaceVariant)),
                ],
              ],
            ),
          ),
          if (trailing != null)
            trailing!
          else
            Icon(Icons.chevron_right_rounded, color: colors.onSurfaceVariant, size: 20),
        ],
      ),
    );
  }
}
