// nano_side_dock_rail.dart — Posiciona la píldora mínima en un lateral.
// QUÉ HACE: Libera el área central después de un arrastre horizontal.
// CÓMO FUNCIONA: Reutiliza NanoNavMiniPill y solo decide izquierda/derecha.
// POR QUÉ: La apariencia mínima tiene una única fuente de verdad.
library;

import 'package:flutter/material.dart';

import 'nano_nav_mini_pill.dart';
import 'nano_destination.dart';

class NanoSideDockRail extends StatelessWidget {
  const NanoSideDockRail({
    super.key,
    required this.onExpandBottom,
    required this.isLeft,
    required this.top,
    this.destination = NanoDestination.automation,
  });

  final VoidCallback onExpandBottom;
  final bool isLeft;
  final double top;
  final NanoDestination destination;

  @override
  Widget build(BuildContext context) => Positioned(
    top: top,
    left: isLeft ? 2 : null,
    right: isLeft ? null : 2,
    child: NanoNavMiniPill(
      semanticLabel: 'Mostrar los cuatro iconos de navegación',
      destination: destination,
      onExpand: onExpandBottom,
    ),
  );
}
