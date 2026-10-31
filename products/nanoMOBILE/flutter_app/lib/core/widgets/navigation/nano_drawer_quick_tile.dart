// nano_drawer_quick_tile.dart — Tile interactivo para accesos rápidos en el Drawer Liquid Glass.
// QUÉ HACE: Renderiza una fila táctil con icono, tipografía e interacción háptica.
// CÓMO FUNCIONA: Despliega fila horizontal con efecto InkWell y feedback táctil.
// POR QUÉ: Divide responsabilidades para mantener los archivos bajo 200 líneas (SOLID).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class NanoDrawerQuickTile extends StatelessWidget {
  const NanoDrawerQuickTile({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.isDark,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6.5),
          child: Row(
            children: [
              Icon(icon, size: 18, color: iconColor),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white70 : const Color(0xFF334155),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
