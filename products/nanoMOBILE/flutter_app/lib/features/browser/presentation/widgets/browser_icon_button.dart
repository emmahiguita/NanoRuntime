import 'package:flutter/material.dart';

/// Botón de acción compacto para la barra del navegador.
///
/// - QUÉ HACE: Renderiza un botón de icono con dimensiones compactas para maximizar el Omnibox.
/// - CÓMO FUNCIONA: Usa un área táctil de 34x34 con icono de 18px y feedback suave.
/// - POR QUÉ: Evita que los botones laterales encogan la barra de direcciones (<200 líneas).
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      width: 34,
      height: 34,
      child: IconButton(
        tooltip: label,
        icon: Icon(icon, size: 18),
        color: isDark ? Colors.white70 : Colors.black87,
        disabledColor: isDark ? Colors.white24 : Colors.black26,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
        onPressed: onPressed,
      ),
    );
  }
}
