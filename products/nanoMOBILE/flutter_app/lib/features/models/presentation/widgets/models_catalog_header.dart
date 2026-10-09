// models_catalog_header.dart — Encabezado editorial del catálogo de modelos.
// QUÉ HACE: Presenta el título legible y una descripción funcional del catálogo.
// CÓMO FUNCIONA: Icono neutro y jerarquía tipográfica con colores del tema claro/oscuro.
// POR QUÉ: Otorga identidad visual profesional conforme al diseño de referencia (< 90 líneas).
library;

import 'package:flutter/material.dart';
import '../../../../core/theme/design_tokens.dart';
import 'model_catalog_surface.dart';

class ModelsCatalogHeader extends StatelessWidget {
  const ModelsCatalogHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;

    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: modelCatalogSurface(context),
              borderRadius: BorderRadius.circular(NanoRadius.medium),
              border: Border.all(color: colors.outlineVariant, width: 0.8),
            ),
            child: Icon(
              Icons.psychology_rounded,
              color: colors.onSurfaceVariant,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Modelos de IA',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                    // En claro no debe desaparecer por usar blanco fijo.
                    color: colors.onSurface,
                  ),
                ),
                Text(
                  'Descarga, importa y administra modelos locales.',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
