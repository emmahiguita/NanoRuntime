// QUÉ: selector compacto para página, ventanas y carrusel.
// CÓMO: un menú Material muestra la vista activa y conserva las tres opciones.
// POR QUÉ: organiza modos avanzados sin quitar ancho a la dirección web.

import 'package:flutter/material.dart';
import 'browser_display_mode.dart';

class BrowserViewModeButton extends StatelessWidget {
  final BrowserDisplayMode mode;
  final int tabCount;
  final ValueChanged<BrowserDisplayMode> onSelected;

  const BrowserViewModeButton({
    super.key,
    required this.mode,
    required this.tabCount,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) => PopupMenuButton<BrowserDisplayMode>(
    tooltip: 'Cambiar vista · $tabCount pestañas',
    useRootNavigator: true,
    initialValue: mode,
    onSelected: onSelected,
    icon: Badge(label: Text('$tabCount'), child: Icon(_icon(mode), size: 20)),
    constraints: const BoxConstraints(minWidth: 224, maxWidth: 300),
    itemBuilder: (_) => [
      _item(BrowserDisplayMode.focused, 'Página activa'),
      _item(BrowserDisplayMode.verticalStack, 'Ventanas y paneles'),
      _item(BrowserDisplayMode.carousel3D, 'Carrusel de pestañas'),
    ],
  );

  PopupMenuItem<BrowserDisplayMode> _item(
    BrowserDisplayMode value,
    String label,
  ) => PopupMenuItem(
    value: value,
    child: Row(
      children: [
        Icon(_icon(value), size: 20),
        const SizedBox(width: 12),
        Expanded(child: Text(label)),
        if (mode == value) const Icon(Icons.check_rounded, size: 18),
      ],
    ),
  );

  static IconData _icon(BrowserDisplayMode value) => switch (value) {
    BrowserDisplayMode.focused => Icons.web_asset_rounded,
    BrowserDisplayMode.verticalStack => Icons.view_agenda_outlined,
    BrowserDisplayMode.carousel3D => Icons.view_carousel_outlined,
  };
}
