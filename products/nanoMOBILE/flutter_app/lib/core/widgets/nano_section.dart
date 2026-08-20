import 'dart:ui';

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
    padding: const EdgeInsets.only(bottom: NanoSpacing.sm, top: NanoSpacing.xs),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: colors.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: NanoIcons.small, color: colors.primary),
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

/// Tarjeta base de Settings (surface + borde + sombra).
class SettingsCard extends StatelessWidget {
  final Widget child;
  final List<BoxShadow>? shadow;
  final NanoColors colors;
  const SettingsCard({
    required this.child,
    this.shadow,
    required this.colors,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = colors is NanoDarkColors;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final borderRadius = BorderRadius.circular(24.0);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: shadow ?? NanoShadows.ambient(colors, depth: 0.8),
      ),
      child: Container(
        padding: const EdgeInsets.all(1.0),
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          gradient: NanoBorders.specularChamfer(colors),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(23.0),
          child: BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: reduceMotion ? 0.0 : 16.0,
              sigmaY: reduceMotion ? 0.0 : 16.0,
            ),
            child: Container(
              padding: const EdgeInsets.all(NanoSpacing.lg),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(23.0),
                gradient: NanoGlass.substrate(
                  colors,
                  opacity: isDark ? colors.glassMedium : 0.78,
                ),
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
