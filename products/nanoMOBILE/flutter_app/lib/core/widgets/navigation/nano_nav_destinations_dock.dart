// nano_nav_destinations_dock.dart — Contenedor horizontal de los 4 destinos en el dock.
// QUÉ HACE: Presenta las 4 pestañas de navegación (Automatización, Modelos, Terminal, Ajustes).
// CÓMO FUNCIONA: Mapea NanoDestination.values y delega en NanoNavDestinationItem con ancho equidistante.
// POR QUÉ: Extraído para cumplir SOLID (SRP), código limpio y estricto límite de < 200 líneas.
library;

import 'package:flutter/material.dart';
import 'nano_destination.dart';
import 'nano_nav_destination_item.dart';

/// Dock horizontal de pestañas de navegación con distribución simétrica.
class NanoNavDestinationsDock extends StatelessWidget {
  final NanoDestination selected;
  final Brightness brightness;
  final ValueChanged<NanoDestination> onSelect;
  final bool compact;

  const NanoNavDestinationsDock({
    super.key,
    required this.selected,
    required this.brightness,
    required this.onSelect,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final d in NanoDestination.values)
          Expanded(
            child: NanoNavDestinationItem(
              destination: d,
              isSelected: selected == d,
              brightness: brightness,
              compact: compact,
              onSelect: onSelect,
            ),
          ),
      ],
    );
  }
}
