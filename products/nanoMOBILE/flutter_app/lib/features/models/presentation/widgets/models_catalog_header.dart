// models_catalog_header.dart — Encabezado editorial del catálogo de modelos.
// QUÉ HACE: Despliega el título "Modelos de IA", subtítulo y eslogan "Rápidos, privados y open-source".
// CÓMO FUNCIONA: Avatar con icono neuronal, textos con jerarquía tipográfica Inter y gradiente sutil.
// POR QUÉ: Otorga identidad visual profesional conforme al diseño de referencia (< 90 líneas).
library;

import 'package:flutter/material.dart';
import '../../../../core/theme/design_tokens.dart';

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
              gradient: const LinearGradient(
                colors: [Color(0xFF0D5E42), Color(0xFF042F2E)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(NanoRadius.medium),
              border: Border.all(
                color: const Color(0xFF10B981).withValues(alpha: 0.5),
                width: 1.2,
              ),
            ),
            child: const Icon(
              Icons.psychology_rounded,
              color: Color(0xFF34D399),
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Modelos de IA',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Modelos locales para tu móvil',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const Text(
                  'Rápidos, privados y open-source.',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF34D399),
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
