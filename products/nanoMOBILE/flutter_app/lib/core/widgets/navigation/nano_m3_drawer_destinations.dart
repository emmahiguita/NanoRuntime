// nano_m3_drawer_destinations.dart — Lista limpia de destinos para el Drawer Liquid Glass.
// QUÉ HACE: Presenta los 4 accesos canónicos de Nano: Inicio, Modelos, Terminal y Ajustes.
// CÓMO FUNCIONA: Usa NanoIosDrawerTile con badges de color semántico, estado activo y feedback háptico.
// POR QUÉ: Diseño minimalista Liquid Glass sin textos redundantes (< 70 líneas).
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'nano_destination.dart';
import 'nano_ios_drawer_section.dart';
import 'nano_ios_drawer_tile.dart';

class NanoM3DrawerDestinations extends StatelessWidget {
  const NanoM3DrawerDestinations({
    super.key,
    required this.selected,
    required this.onSelect,
  });

  final NanoDestination selected;
  final ValueChanged<NanoDestination> onSelect;

  @override
  Widget build(BuildContext context) {
    return NanoIosDrawerSection(
      title: 'Navegación',
      children: [
        NanoIosDrawerTile(
          icon: CupertinoIcons.house_fill,
          iconColor: const Color(0xFF007AFF),
          title: 'Inicio',
          isSelected: selected == NanoDestination.automation,
          showDivider: true,
          onTap: () => onSelect(NanoDestination.automation),
        ),
        NanoIosDrawerTile(
          icon: CupertinoIcons.cube_box_fill,
          iconColor: const Color(0xFF5856D6),
          title: 'Modelos',
          isSelected: selected == NanoDestination.models,
          showDivider: true,
          onTap: () => onSelect(NanoDestination.models),
        ),
        NanoIosDrawerTile(
          icon: Icons.terminal_rounded,
          iconColor: const Color(0xFF30B0C7),
          title: 'Terminal',
          isSelected: selected == NanoDestination.terminal,
          showDivider: true,
          onTap: () => onSelect(NanoDestination.terminal),
        ),
        NanoIosDrawerTile(
          icon: CupertinoIcons.gear_alt_fill,
          iconColor: const Color(0xFF8E8E93),
          title: 'Ajustes',
          isSelected: selected == NanoDestination.settings,
          showDivider: false,
          onTap: () => onSelect(NanoDestination.settings),
        ),
      ],
    );
  }
}
