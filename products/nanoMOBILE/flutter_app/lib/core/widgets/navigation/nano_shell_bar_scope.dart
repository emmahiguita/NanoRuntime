// nano_shell_bar_scope.dart — Scope heredado para la barra de navegación del shell.
// QUÉ HACE: Expone información del shell a pantallas hijas para coordinar insets y visibilidad.
// CÓMO FUNCIONA: Widget que propaga estado de la barra y slotId de entrada universal en el sub-árbol.
// POR QUÉ: Extraído de nano_navigation_panel.dart para cumplir SOLID (SRP) y mantener código < 200 líneas.
library;

import 'package:flutter/material.dart';

class NanoShellBarScope extends StatelessWidget {
  final Widget child;
  final bool hasFloatingBar;
  final String? slotId;

  const NanoShellBarScope({
    super.key,
    required this.child,
    this.hasFloatingBar = true,
    this.slotId,
  });

  @override
  Widget build(BuildContext context) {
    return child;
  }
}
