// nano_destination_icon.dart — Iconos vectoriales profesionales estilo iOS para la barra de navegación.
//
// QUÉ HACE:
// Renderiza el icono vectorial canónico para cada destino principal:
// Inicio (casa sólida), Modelos (cubo 3D de IA), Terminal (símbolo de comando) y Ajustes.
//
// CÓMO FUNCIONA:
// Mapea directamente a glifos nítidos CupertinoIcons y Material Rounded sin distorsión.
//
// POR QUÉ:
// Asegura consistencia visual idéntica a iOS Liquid Glass y legibilidad óptica (< 50 líneas, SOLID).
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'nano_destination.dart';

class NanoDestinationIcon extends StatelessWidget {
  const NanoDestinationIcon({
    super.key,
    required this.destination,
    this.size = 22,
    this.color,
  });

  final NanoDestination destination;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? Theme.of(context).colorScheme.onSurface;
    final iconData = switch (destination) {
      NanoDestination.automation => CupertinoIcons.house_fill,
      NanoDestination.models => CupertinoIcons.cube_box_fill,
      NanoDestination.terminal => Icons.terminal_rounded,
      NanoDestination.settings => CupertinoIcons.gear_alt_fill,
    };

    return Icon(
      iconData,
      size: size,
      color: effectiveColor,
    );
  }
}
