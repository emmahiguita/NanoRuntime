import 'package:flutter/material.dart';
import 'package:nanoai/core/theme/design_tokens.dart';
import 'package:nanoai/core/theme/nano_type.dart';

/// Encabezado de sección de Settings: icono + título en overline.
/// Compartido por la pantalla y las secciones en widgets/.
class SectionHeader extends StatelessWidget {
  final String text;
  final IconData icon;
  final NanoColors colors;
  final Color? iconColor;
  const SectionHeader(this.text, this.icon, {
    required this.colors,
    this.iconColor,
    super.key,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: NanoSpacing.sm, top: NanoSpacing.xs),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: iconColor?.withValues(alpha: 0.12) ??
                colors.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: NanoIcons.small, color: iconColor ?? colors.primary),
        ),
        const SizedBox(width: NanoSpacing.sm),
        Text(
          text.toUpperCase(),
          style: NanoType.overline(colors.onSurfaceVariant),
        ),
      ],
    ),
  );
}
