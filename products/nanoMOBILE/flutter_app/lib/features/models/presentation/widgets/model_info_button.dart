import 'package:flutter/material.dart';
import 'package:nanoai/core/theme/design_tokens.dart';

/// Botón de información accesible que no depende de un [Overlay].
///
/// La pantalla vive dentro de pilas personalizadas; usar `Tooltip` allí podía
/// mostrar el ErrorWidget rojo "No Overlay". [Semantics] conserva la etiqueta
/// para lectores de pantalla sin crear entradas flotantes.
class ModelInfoButton extends StatelessWidget {
  const ModelInfoButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: colors.backgroundSecondary.withValues(alpha: 0.50),
            border: Border.all(
              color: colors.borderSecondaryColor.withValues(alpha: 0.30),
              width: 0.7,
            ),
          ),
          child: Icon(icon, size: 13, color: colors.accentMint),
        ),
      ),
    );
  }
}
