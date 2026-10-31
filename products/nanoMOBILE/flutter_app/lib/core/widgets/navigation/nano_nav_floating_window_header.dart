// nano_nav_floating_window_header.dart — Cabecera iOS Liquid Glass del menú de navegación.
// QUÉ HACE: Renderiza el título de navegación con icono de cuadrícula iOS según diseño de referencia.
// CÓMO FUNCIONA: Presenta icono en azul de marca, tipografía seminegrita y divisor sutil.
// POR QUÉ: Consistencia visual 100% fiel a la guía iOS con límites estrictos < 200 líneas (< 70 líneas).
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class NanoNavFloatingWindowHeader extends StatelessWidget {
  const NanoNavFloatingWindowHeader({
    super.key,
    this.onRestoreBottom,
    this.onCloseMenu,
  });

  final VoidCallback? onRestoreBottom;
  final VoidCallback? onCloseMenu;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    const brandBlue = Color(0xFF2563EB);

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 2, 4, 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(
                CupertinoIcons.square_grid_2x2_fill,
                size: 19,
                color: brandBlue,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Navegación',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.25,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Divider(
            height: 1,
            thickness: 0.6,
            color: isDark
                ? Colors.white.withValues(alpha: 0.12)
                : Colors.black.withValues(alpha: 0.07),
          ),
        ],
      ),
    );
  }
}
