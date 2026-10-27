import 'package:flutter/material.dart';

/// QUÉ: organiza campos de edición sin fijar alturas ni orientación del equipo.
/// CÓMO: una columna estrecha y dos columnas cuando el ancho útil lo permite.
/// POR QUÉ: en horizontal se aprovecha el espacio y con teclado/texto grande se puede desplazar.
class AdaptivePersonalFields extends StatelessWidget {
  const AdaptivePersonalFields({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (_, constraints) {
      if (constraints.maxWidth < 560) return Column(children: children);
      final width = (constraints.maxWidth - 12) / 2;
      return Wrap(
        spacing: 12,
        runSpacing: 4,
        children: [
          for (final child in children) SizedBox(width: width, child: child),
        ],
      );
    },
  );
}
