import 'package:flutter/material.dart';

/// Aísla la perspectiva visual para que el WebView conserve su estado al rotar.
class Browser3DCarouselPage extends StatelessWidget {
  const Browser3DCarouselPage({
    super.key,
    required this.controller,
    required this.index,
    required this.currentPage,
    required this.onActivate,
    required this.child,
  });

  final PageController controller;
  final int index;
  final int currentPage;
  final VoidCallback onActivate;
  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    child: child,
    builder: (context, pageChild) {
      // Antes de tener métricas usa la página seleccionada; evita leer una posición aún no adjunta.
      final hasMetrics =
          controller.hasClients && controller.position.haveDimensions;
      final distance =
          ((hasMetrics ? controller.page : null) ?? currentPage.toDouble()) -
          index;
      final scale = (1.0 - (distance.abs() * 0.12)).clamp(0.86, 1.0);
      final translateY = (distance.abs() * 16.0).clamp(0.0, 26.0);
      final dim = (distance.abs() * 0.35).clamp(0.0, 0.45);
      final isCurrent = index == currentPage;
      Widget card = Stack(
        children: [
          IgnorePointer(ignoring: !isCurrent, child: pageChild!),
          if (dim > 0.02)
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: dim),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
        ],
      );
      if (!isCurrent) {
        card = GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onActivate,
          child: card,
        );
      }
      return Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..translateByDouble(0.0, translateY, 0.0, 1.0)
          ..scaleByDouble(scale, scale, 1.0, 1.0),
        child: card,
      );
    },
  );
}
