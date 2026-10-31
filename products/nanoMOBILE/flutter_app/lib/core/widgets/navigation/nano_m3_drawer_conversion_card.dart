// nano_m3_drawer_conversion_card.dart — Botón de retorno a la barra de navegación flotante.
// QUÉ HACE: Renderiza la acción limpia para cerrar el Drawer y restaurar la barra inferior flotante.
// CÓMO FUNCIONA: Usa InkWell con borde sutil, icono Cupertino y texto claro en tipografía Inter.
// POR QUÉ: Permite volver a la barra flotante con feedback táctil inmediato (< 80 líneas).
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class NanoM3DrawerConversionCard extends StatelessWidget {
  const NanoM3DrawerConversionCard({
    super.key,
    required this.onConvertToBottomBar,
  });

  final VoidCallback onConvertToBottomBar;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          HapticFeedback.mediumImpact();
          onConvertToBottomBar();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.black.withValues(alpha: 0.035),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.06),
              width: 0.8,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                CupertinoIcons.arrow_down_to_line,
                size: 16,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Volver a barra flotante',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
