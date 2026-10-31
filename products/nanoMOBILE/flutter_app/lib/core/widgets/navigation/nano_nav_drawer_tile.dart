// nano_nav_drawer_tile.dart — Fila interactiva para el Drawer lateral Liquid Glass.
// QUÉ HACE:
// Renderiza una opción de navegación vertical en la ventana del Drawer lateral,
// mostrando el icono canónico, la etiqueta descriptiva y un indicador de selección activo.
//
// CÓMO FUNCIONA:
// Al hacer tap, emite feedback háptico suave (selectionClick), notifica al callback
// onSelect con el NanoDestination correspondiente y resalta la cápsula activa.
//
// POR QUÉ:
// Aplica el principio de Responsabilidad Única (SRP de SOLID): aísla la presentación
// y accesibilidad de cada ítem del Drawer en menos de 100 líneas limpias y legibles.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'nano_destination.dart';
import 'nano_destination_icon.dart';

class NanoNavDrawerTile extends StatelessWidget {
  const NanoNavDrawerTile({
    super.key,
    required this.destination,
    required this.isSelected,
    required this.onTap,
  });

  final NanoDestination destination;
  final bool isSelected;
  final VoidCallback onTap;

  String _destinationLabel(NanoDestination dest) {
    switch (dest) {
      case NanoDestination.automation:
        return 'Inicio';
      case NanoDestination.models:
        return 'Modelos locales';
      case NanoDestination.terminal:
        return 'Terminal Linux';
      case NanoDestination.settings:
        return 'Ajustes';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final label = _destinationLabel(destination);

    final activeBackground = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : scheme.primary.withValues(alpha: 0.10);
    final activeBorder = isDark
        ? Colors.white.withValues(alpha: 0.22)
        : scheme.primary.withValues(alpha: 0.25);

    return Semantics(
      button: true,
      selected: isSelected,
      label: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: AnimatedContainer(
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? activeBackground : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected ? activeBorder : Colors.transparent,
                width: 0.8,
              ),
            ),
            child: Row(
              children: [
                NanoDestinationIcon(
                  destination: destination,
                  size: 21,
                  color: isSelected
                      ? (isDark ? Colors.white : scheme.primary)
                      : scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected
                          ? (isDark ? Colors.white : scheme.primary)
                          : scheme.onSurface,
                      letterSpacing: -0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isSelected)
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDark ? Colors.white : scheme.primary,
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
