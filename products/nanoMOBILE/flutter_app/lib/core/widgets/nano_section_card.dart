import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';
import '../theme/nano_type.dart';

/// Tarjeta de sección con título para superficies de diagnóstico (pantalla
/// Dev). Una sola definición: las secciones del edge y de automation la
/// comparten en lugar de duplicar el mismo layout privado.
class NanoSectionCard extends StatelessWidget {
  const NanoSectionCard({super.key, required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            NanoSpacing.sm,
            0,
            NanoSpacing.sm,
            NanoSpacing.sm,
          ),
          child: Text(title, style: NanoType.title(colors.onSurface)),
        ),
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(NanoSpacing.md),
            child: child,
          ),
        ),
      ],
    );
  }
}
