// nano_ios_drawer_section.dart — Grupo de opciones estilo Inset Grouped de iOS.
// QUÉ HACE: Agrupa celdas de navegación dentro de una tarjeta redondeada translúcida.
// CÓMO FUNCIONA: Presenta encabezado en mayúsculas pequeñas y contenedor con borde y clip anti-alias.
// POR QUÉ: Otorga la apariencia nativa de iOS Settings / iPad Sidebar manteniendo < 100 líneas.
library;

import 'package:flutter/material.dart';

class NanoIosDrawerSection extends StatelessWidget {
  const NanoIosDrawerSection({
    super.key,
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. Título de sección en mayúsculas estilo iOS
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 6, 10, 5),
            child: Text(
              title.toUpperCase(),
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.6,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.50)
                    : scheme.onSurfaceVariant.withValues(alpha: 0.70),
              ),
            ),
          ),
          // 2. Tarjeta Inset Grouped redondeada
          Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.black.withValues(alpha: 0.035),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.06),
                width: 0.8,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}
