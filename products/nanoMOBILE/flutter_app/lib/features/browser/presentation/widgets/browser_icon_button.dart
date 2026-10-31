import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// QUÉ HACE:
/// Botón de acción circular compacto estilo iOS para la barra de navegación web.
///
/// CÓMO FUNCIONA:
/// Usa un área táctil de 34x34 con icono centrado de 17px, bordes redondeados y feedback háptico.
///
/// POR QUÉ:
/// Entrega una respuesta táctil nativa y limpia sin recortes ni desbordamientos (< 50 líneas).
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
    final enabled = onPressed != null;

    return Semantics(
      button: true,
      label: label,
      enabled: enabled,
      child: Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(17),
            onTap: enabled
                ? () {
                    HapticFeedback.lightImpact();
                    onPressed!();
                  }
                : null,
            child: Padding(
              padding: const EdgeInsets.all(7),
              child: Icon(
                icon,
                size: 18,
                color: enabled
                    ? (isDark ? Colors.white : const Color(0xFF0F172A))
                    : (isDark ? Colors.white24 : Colors.black26),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
