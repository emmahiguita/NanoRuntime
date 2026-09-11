import 'package:flutter/material.dart';

/// Transformación 3D Cover Flow matemática (OCP / SRP).
///
/// Aplica rotación sobre el eje Y con perspectiva real (m44),
/// escala suave por distancia al centro y compensación de posición.
class PerspectiveCarouselItem extends StatelessWidget {
  const PerspectiveCarouselItem({
    super.key,
    required this.delta,
    required this.child,
  });

  final double delta;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final double normalized = delta.clamp(-1.5, 1.5).toDouble();
    final double distance = normalized.abs().clamp(0.0, 1.0).toDouble();

    // Inclinación suave de aproximadamente 21.8°
    final double angleY = normalized * 0.38;

    // Elemento central = 1.0, laterales decrecientes
    final double scale = 1.0 - (distance * 0.16);
    final double verticalOffset = distance * 18;
    final double horizontalOffset = -normalized * 10;

    return Transform.translate(
      offset: Offset(horizontalOffset, verticalOffset),
      child: Transform.scale(
        scale: scale,
        child: Transform(
          alignment:
              normalized > 0 ? Alignment.centerLeft : Alignment.centerRight,
          transform: Matrix4.identity()
            ..setEntry(3, 2, -0.00135)
            ..rotateY(angleY),
          child: Opacity(
            opacity: (1.0 - (distance * 0.22)).clamp(0.0, 1.0),
            child: child,
          ),
        ),
      ),
    );
  }
}
