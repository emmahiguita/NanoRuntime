// nano_nav_floating_row.dart — Fila de destino estilo iOS Liquid Glass.
// QUÉ HACE: Renderiza cada opción de navegación con icono, tipografía e indicador activo circular.
// CÓMO FUNCIONA: Usa cápsula tintada activa, acento azul de marca (#2563EB) y dot indicador a la derecha.
// POR QUÉ: Consistencia visual 100% idéntica a la guía de referencia iOS manteniendo SRP (< 100 líneas).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'nano_destination.dart';
import 'nano_destination_icon.dart';

class NanoNavFloatingRow extends StatelessWidget {
  const NanoNavFloatingRow({
    super.key,
    required this.destination,
    required this.isSelected,
    required this.onTap,
  });

  final NanoDestination destination;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    const brandBlue = Color(0xFF2563EB);

    final label = destination == NanoDestination.automation
        ? 'Inicio'
        : destination.label;

    final activeBg = isDark
        ? brandBlue.withValues(alpha: 0.22)
        : const Color(0xFFEFF6FF);

    final iconColor = isSelected
        ? brandBlue
        : (isDark
            ? Colors.white.withValues(alpha: 0.75)
            : const Color(0xFF475569));

    final textColor = isSelected
        ? brandBlue
        : (isDark
            ? Colors.white.withValues(alpha: 0.88)
            : const Color(0xFF1E293B));

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: isSelected ? activeBg : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8.5),
            child: Row(
              children: [
                NanoDestinationIcon(
                  destination: destination,
                  size: 20,
                  color: iconColor,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: textColor,
                    ),
                  ),
                ),
                if (isSelected)
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: brandBlue,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
