import 'package:flutter/material.dart';

/// Tirador interactivo de arrastre y control de altura vertical para la terminal.
///
/// QUÉ HACE:
/// Permite al usuario arrastrar hacia arriba o abajo para regular la altura visible
/// de la consola interactiva en tiempo real, o hacer doble toque para alternar alturas.
///
/// CÓMO FUNCIONA:
/// Captura gestos verticales vía [GestureDetector] y emite deltas porcentuales
/// normalizados según la altura máxima de la pantalla, evitando rebuilds innecesarios.
///
/// POR QUÉ:
/// En pantallas móviles y tablets, la consola necesita convivir con herramientas auxiliares
/// o expandirse a pantalla completa cuando se editan archivos con nano/vim.
class TerminalHeightResizeHandle extends StatelessWidget {
  final Color handleColor;
  final ValueChanged<double> onVerticalDragDelta;
  final VoidCallback onDoubleTap;

  const TerminalHeightResizeHandle({
    super.key,
    required this.handleColor,
    required this.onVerticalDragDelta,
    required this.onDoubleTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragUpdate: (details) {
        onVerticalDragDelta(details.primaryDelta ?? 0.0);
      },
      onDoubleTap: onDoubleTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 4),
        color: Colors.transparent,
        child: Center(
          child: Container(
            width: 48,
            height: 4.5,
            decoration: BoxDecoration(
              color: handleColor.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ),
      ),
    );
  }
}
