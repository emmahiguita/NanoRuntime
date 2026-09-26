// model_spec_tile.dart — Tarjeta óptica de especificación individual de modelo.
// QUÉ HACE: Renderiza una cápsula con icono, etiqueta y valor (parámetros, RAM requerida, cuantización).
// CÓMO FUNCIONA: Utiliza NanoOpticalSurface con tipografía Inter y micro-layout responsivo.
// POR QUÉ: Extraído para mantener componentes atómicos, reusables y código < 200 líneas.
library;

import 'package:flutter/material.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/nano_optical_surface.dart';

class ModelSpecTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const ModelSpecTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;

    return NanoOpticalSurface(
      borderRadius: NanoRadius.small,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: colors.primary),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 9.5,
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: colors.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
