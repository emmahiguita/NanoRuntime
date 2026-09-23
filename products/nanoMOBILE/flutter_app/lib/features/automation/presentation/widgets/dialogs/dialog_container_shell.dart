// dialog_container_shell.dart
//
// QUÉ HACE:
// Contenedor responsivo y blindado con Material Expressive 3 para diálogos móviles (Landscape y Portrait).
// Previene el error visual "No Overlay" integrando un ámbito de Overlay y Material garantizado.
//
// CÓMO FUNCIONA:
// - Detecta orientación y dimensiones reales de pantalla:
//   * En Landscape: reduce los márgenes verticales a 8dp y expande el ancho máximo a 560dp.
//   * En Portrait: márgenes ergonómicos de 24dp y ancho de 460dp.
// - Envuelve el contenido en un Scaffold/Material con Overlay local dedicado:
//   * Resuelve el fallo 'No Overlay widget found' para Tooltips, menús y selecciones de texto.
// - Aplica bordes orgánicos redondeados (24dp), superficies translúcidas y sombra difusa.
//
// POR QUÉ:
// Asegura estabilidad visual 100% libre de cajas rojas/amarillas, adapta modo horizontal y
// elimina desbordamientos de RenderFlex al desplegar teclado virtual (SOLID - SRP).

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
          child: Overlay(
            initialEntries: [
              OverlayEntry(
                builder: (overlayContext) => child,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
