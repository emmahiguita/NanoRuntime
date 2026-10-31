// nano_side_dock_rail.dart — Posiciona el Drawer lateral Liquid Glass o la píldora mínima.
// QUÉ HACE:
// Despliega la ventana lateral del Drawer cuando la navegación se arrastra a la izquierda,
// o la píldora mínima lateral si se ubica en el extremo derecho.
//
// CÓMO FUNCIONA:
// Aloja NanoNavSideDrawer en una posición flotante izquierda con animación elástica de entrada.
//
// POR QUÉ:
// Conecta el gesto horizontal a la izquierda con el Drawer lateral completo con ventana,
// manteniendo el código modular y por debajo de 100 líneas.
library;

import 'package:flutter/material.dart';
import 'nano_destination.dart';
import 'nano_nav_mini_pill.dart';
import 'nano_nav_side_drawer.dart';

class NanoSideDockRail extends StatelessWidget {
  const NanoSideDockRail({
    super.key,
    required this.onExpandBottom,
    required this.isLeft,
    required this.top,
    this.destination = NanoDestination.automation,
    this.onDestinationSelected,
  });

  final VoidCallback onExpandBottom;
  final bool isLeft;
  final double top;
  final NanoDestination destination;
  final ValueChanged<NanoDestination>? onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    if (isLeft) {
      return Positioned(
        left: 12,
        top: top,
        child: NanoNavSideDrawer(
          selected: destination,
          onDestinationSelected: onDestinationSelected ?? (_) {},
          onRestoreBottom: onExpandBottom,
        ),
      );
    }

    return Positioned(
      top: top,
      right: 4,
      child: NanoNavMiniPill(
        semanticLabel: 'Mostrar navegación',
        destination: destination,
        onExpand: onExpandBottom,
      ),
    );
  }
}
