// QUÉ: superficie neutra compartida exclusivamente por el catálogo.
// CÓMO: mezcla un leve tono del texto sobre la superficie del tema.
// POR QUÉ: evita propagar los fondos verdes del tema global a este módulo.
import 'package:flutter/material.dart';

Color modelCatalogSurface(BuildContext context) {
  final colors = Theme.of(context).colorScheme;
  return Color.alphaBlend(
    colors.onSurface.withValues(alpha: 0.05),
    colors.surface,
  );
}
