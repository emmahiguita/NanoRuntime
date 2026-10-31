// nano_fab_menu_item.dart — Ítem interactivo del menú vertical de Nano FAB.
//
// QUÉ HACE: Renderiza una fila táctil con icono coloreado y etiqueta semántica.
// CÓMO FUNCIONA: Usa InkWell, contenedor de icono con bordes redondeados y Semantics accesible.
// POR QUÉ: Extrae la responsabilidad visual del ítem garantizando archivos < 80 líneas (SOLID).
library;

import 'package:flutter/material.dart';

/// Elemento táctil individual de cada opción del menú FAB.
class NanoFabMenuItem extends StatelessWidget {
  const NanoFabMenuItem({
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
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: isDark ? 0.22 : 0.14),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 17, color: iconColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
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
