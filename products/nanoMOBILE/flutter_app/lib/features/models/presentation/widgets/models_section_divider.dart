// QUÉ: encabezado de sección sobrio, sin barras de acento decorativas.
// CÓMO: texto legible que puede envolver y un separador del tema.
// POR QUÉ: conserva la jerarquía y el recuento sin cortar títulos en teléfonos.
import 'package:flutter/material.dart';

class ModelsSectionDivider extends StatelessWidget {
  final String label;
  const ModelsSectionDivider({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Divider(height: 1, color: theme.colorScheme.outlineVariant),
        ],
      ),
    );
  }
}
