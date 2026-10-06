import 'package:flutter/material.dart';

/// Botón uniforme: icono compacto y área táctil Material de 48 píxeles.
/// El callback nulo deshabilita de verdad acciones que no están disponibles.
class BrowserIconButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  const BrowserIconButton({
    super.key,
    required this.icon,
    required this.label,
    this.onPressed,
  });

  /// Usa el tema existente; no asigna un color distinto a cada acción.
  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: label,
    icon: Icon(icon, size: 20),
    onPressed: onPressed,
    constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
    style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
  );
}
