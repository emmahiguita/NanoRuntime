// models_section_divider.dart — Separador tipográfico de categorías de modelos.
// QUÉ HACE: Renderiza la barra vertical de acento, etiqueta en mayúsculas y línea divisoria.
// CÓMO FUNCIONA: Row con contenedor coloreado, texto Inter y divisor expandido.
// POR QUÉ: Extraído para mantener modularidad limpia y cumplir la regla < 200 líneas (SRP).
library;

import 'package:flutter/material.dart';
import '../../../../core/theme/design_tokens.dart';

class ModelsSectionDivider extends StatelessWidget {
  final String label;
  final Color? color;

  const ModelsSectionDivider({
    super.key,
    required this.label,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;
    final effectiveColor =
        color ?? colors.onSurfaceVariant.withValues(alpha: 0.5);

    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: Row(
        children: [
          Container(
            width: 3.5,
            height: 13,
            decoration: BoxDecoration(
              color: effectiveColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.7,
                color: effectiveColor,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 0.5,
              color: effectiveColor.withValues(alpha: 0.22),
            ),
          ),
        ],
      ),
    );
  }
}
