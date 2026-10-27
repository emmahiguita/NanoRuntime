// QUÉ: encabezado de familia con recuento real en tonos neutros.
// CÓMO: texto flexible y recuento separado; reutiliza la interfaz existente.
// POR QUÉ: evita desbordamientos y mantiene los componentes por debajo de 200 líneas.
import 'package:flutter/material.dart';

class IosSectionHeader extends StatelessWidget {
  final String title;
  final int count;
  const IosSectionHeader({super.key, required this.title, required this.count});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 4, top: 12, bottom: 6),
      child: Row(
        children: [
          Expanded(child: Text(title, style: theme.textTheme.labelLarge)),
          const SizedBox(width: 8),
          Text(
            '$count',
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
