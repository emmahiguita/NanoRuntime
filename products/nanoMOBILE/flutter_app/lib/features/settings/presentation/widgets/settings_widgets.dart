import 'package:flutter/material.dart';
import 'package:nanoai/core/theme/design_tokens.dart';
import 'package:nanoai/core/theme/nano_type.dart';

/// Encabezado de sección de Settings: icono + título en overline.
/// Compartido por la pantalla y las secciones en widgets/.
class SectionHeader extends StatelessWidget {
  final String text;
  final IconData icon;
  final NanoColors colors;
  const SectionHeader(this.text, this.icon, {
    required this.colors,
    super.key,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: NanoSpacing.sm),
    child: Row(
      children: [
        Icon(icon, size: NanoIcons.small, color: colors.primary),
        const SizedBox(width: NanoSpacing.sm),
        Text(
          text.toUpperCase(),
          style: NanoType.overline(colors.onSurfaceVariant),
        ),
      ],
    ),
  );
}

/// Tarjeta base de Settings (surface + borde + sombra).
class SettingsCard extends StatelessWidget {
  final Widget child;
  final List<BoxShadow> shadow;
  final NanoColors colors;
  const SettingsCard({
    required this.child,
    required this.shadow,
    required this.colors,
    super.key,
  });

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(NanoSpacing.lg),
    decoration: BoxDecoration(
      color: colors.surface,
      borderRadius: NanoShapes.large,
      border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.4)),
      boxShadow: shadow,
    ),
    child: child,
  );
}
