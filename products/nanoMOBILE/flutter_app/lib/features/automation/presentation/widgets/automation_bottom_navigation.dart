import 'package:flutter/material.dart';

/// Contenedor de pantalla para automatización.
///
/// La navegación principal vive exclusivamente en el shell de la aplicación
/// (`ScaffoldShell`) para evitar barras duplicadas y mantener una experiencia
/// limpia y profesional.
class AutomationNavigationFrame extends StatelessWidget {
  const AutomationNavigationFrame({
    super.key,
    required this.child,
    this.onAutomationTap,
    this.hidden = false,
  });

  final Widget child;
  final VoidCallback? onAutomationTap;
  final bool hidden;

  @override
  Widget build(BuildContext context) {
    return child;
  }
}
