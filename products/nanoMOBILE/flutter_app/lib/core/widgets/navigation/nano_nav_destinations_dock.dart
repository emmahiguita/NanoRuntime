// nano_nav_destinations_dock.dart — Contenedor Liquid Glass con 3 destinos y Nano FAB.
//
// QUÉ HACE:
// Presenta la barra de navegación inferior con exactamente tres destinos principales
// proporcionales (Inicio, Modelos, Terminal) y el Nano FAB circular en el extremo derecho.
//
// CÓMO FUNCIONA:
// - Distribuye equitativamente Inicio, Modelos y Terminal mediante Expanded.
// - Aplica una píldora lavanda sutil animada con esquinas continuas sobre el destino activo.
// - Ancla el botón circular independiente Nano FAB en la derecha respetando la referencia visual.
//
// POR QUÉ:
// Satisface la distribución obligatoria estilo iOS Liquid Glass (< 120 líneas, SOLID).
library;

import 'package:flutter/material.dart';
import 'nano_destination.dart';
import 'nano_fab_button.dart';
import 'nano_nav_destination_item.dart';

/// Barra de navegación flotante Liquid Glass con 3 accesos y Nano FAB.
class NanoNavDestinationsDock extends StatelessWidget {
  const NanoNavDestinationsDock({
    super.key,
    required this.selected,
    required this.brightness,
    required this.onSelect,
    this.compact = false,
  });

  final NanoDestination selected;
  final Brightness brightness;
  final ValueChanged<NanoDestination> onSelect;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final isDark = brightness == Brightness.dark;
    const destinations = NanoDestination.bottomBarDestinations;

    // Fondo lavanda sutil para el estado activo inspirado en el diseño de referencia.
    final activePillColor = isDark
        ? const Color(0xFF6366F1).withValues(alpha: 0.22)
        : const Color(0xFFEDE9FE).withValues(alpha: 0.88);

    final activePillBorder = isDark
        ? const Color(0x35818CF8)
        : const Color(0x40A5B4FC);

    return Row(
      children: [
        // 1. Destinos principales proporcionales: Inicio, Modelos, Terminal
        for (final destination in destinations)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2.5),
              child: AnimatedContainer(
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                decoration: BoxDecoration(
                  color: selected == destination
                      ? activePillColor
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: selected == destination
                        ? activePillBorder
                        : Colors.transparent,
                    width: 0.8,
                  ),
                  boxShadow: selected == destination
                      ? const [
                          BoxShadow(
                            color: Color(0x146366F1),
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: NanoNavDestinationItem(
                  destination: destination,
                  isSelected: selected == destination,
                  brightness: brightness,
                  compact: compact,
                  onSelect: onSelect,
                ),
              ),
            ),
          ),

        // Separación sutil antes del FAB independiente
        const SizedBox(width: 4),

        // 2. Nano FAB independiente en el extremo derecho
        Padding(
          padding: const EdgeInsets.only(left: 2, right: 2),
          child: NanoFabButton(
            size: compact ? 44.0 : 48.0,
            brightness: brightness,
          ),
        ),
      ],
    );
  }
}
