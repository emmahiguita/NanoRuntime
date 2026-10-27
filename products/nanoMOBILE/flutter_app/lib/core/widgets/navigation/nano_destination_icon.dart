// QUÉ: icono propio asociado a cada destino real de la barra.
// CÓMO: comparte una sola correspondencia entre el estado abierto y el reducido.
// POR QUÉ: el usuario reconoce la sección incluso cuando la barra se contrae.
import 'package:flutter/material.dart';
import '../feather_core_icon.dart';
import 'nano_destination.dart';

class NanoDestinationIcon extends StatelessWidget {
  const NanoDestinationIcon({
    super.key,
    required this.destination,
    this.size = 24,
    this.color,
  });
  final NanoDestination destination;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) => FeatherCoreIcon(
    type: switch (destination) {
      NanoDestination.automation => FeatherCoreType.home,
      NanoDestination.models => FeatherCoreType.models,
      NanoDestination.terminal => FeatherCoreType.terminal,
      NanoDestination.settings => FeatherCoreType.settings,
    },
    size: size,
    framed: false,
    accentColor: color ?? Theme.of(context).colorScheme.onSurfaceVariant,
  );
}
