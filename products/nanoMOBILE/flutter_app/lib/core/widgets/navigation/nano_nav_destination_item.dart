// nano_nav_destination_item.dart — Destino individual del dock inferior compacto.
//
// QUÉ HACE:
// Renderiza el icono vectorial y la etiqueta tipográfica para un destino de navegación
// con estética profesional estilo iOS Liquid Glass.
//
// CÓMO FUNCIONA:
// - Despliega NanoDestinationIcon (21dp) y texto nítido Inter (10.5dp).
// - En estado activo aplica color de acento índigo/lavanda y peso seminegrita.
// - En estado inactivo muestra gris pizarra suave sin saturar visualmente la barra.
// - Provee área táctil accesible de al menos 48dp de alto con feedback háptico.
//
// POR QUÉ:
// Asegura consistencia visual, fidelidad iOS y accesibilidad (< 100 líneas, SOLID).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'nano_destination.dart';
import 'nano_destination_icon.dart';

class NanoNavDestinationItem extends StatelessWidget {
  const NanoNavDestinationItem({
    super.key,
    required this.destination,
    required this.isSelected,
    required this.brightness,
    required this.onSelect,
    this.compact = false,
  });

  final NanoDestination destination;
  final bool isSelected;
  final Brightness brightness;
  final ValueChanged<NanoDestination> onSelect;
  final bool compact;

  void _activate() {
    if (isSelected) return;
    HapticFeedback.selectionClick();
    onSelect(destination);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = brightness == Brightness.dark;
    final label = destination == NanoDestination.automation
        ? 'Inicio'
        : destination.label;

    final iconColor = isSelected
        ? (isDark ? const Color(0xFFA5B4FC) : const Color(0xFF4F46E5))
        : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B));

    final textColor = isSelected
        ? (isDark ? const Color(0xFFF1F5F9) : const Color(0xFF312E81))
        : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B));

    return Semantics(
      button: true,
      selected: isSelected,
      label: label,
      excludeSemantics: true,
      onTap: _activate,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: _activate,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  NanoDestinationIcon(
                    destination: destination,
                    size: 21,
                    color: iconColor,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 10.5,
                      height: 1.15,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: textColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
