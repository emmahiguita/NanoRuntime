// dialog_container_shell.dart
//
// QUÉ HACE:
// Contenedor adaptativo Material 3 que conserva el diseño de los diálogos.
//
// CÓMO FUNCIONA:
// - Detecta orientación y dimensiones reales de pantalla:
//   * En Landscape: reduce los márgenes verticales a 8dp y expande el ancho máximo a 560dp.
//   * En Portrait: márgenes ergonómicos de 24dp y ancho de 460dp.
// - Proporciona Material y Overlay local para menús y selección de texto.
// - Aplica bordes orgánicos redondeados (24dp), superficies translúcidas y sombra difusa.
//
// POR QUÉ:
// Centraliza dimensiones y superficie; el contenido conserva su propia lógica.

import 'package:flutter/material.dart';
import 'package:nanoai/features/automation/presentation/automation_visual_theme.dart';

class DialogContainerShell extends StatelessWidget {
  final Widget child;
  final double maxWidthPortrait;
  final double maxWidthLandscape;

  const DialogContainerShell({
    super.key,
    required this.child,
    this.maxWidthPortrait = 460,
    this.maxWidthLandscape = 560,
  });

  @override
  // Ajusta el ancho según la ventana; Dialog descuenta los insets del teclado.
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isLandscape = size.width > size.height;
    final visual = AutomationVisual.of(context);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: 16,
        vertical: isLandscape ? 8 : 24,
      ),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: isLandscape ? maxWidthLandscape : maxWidthPortrait,
          maxHeight: size.height * (isLandscape ? 0.92 : 0.85),
        ),
        decoration: BoxDecoration(
          color: visual.isDark ? const Color(0xFF0F172A) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: visual.isDark
                ? Colors.white.withValues(alpha: 0.16)
                : const Color(0xFFCBD5E1),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 28,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Material(
          color: Colors.transparent,
          // wrap reconstruye el hijo y gestiona remove/dispose de la entrada.
          child: Overlay.wrap(child: child),
        ),
      ),
    );
  }
}
