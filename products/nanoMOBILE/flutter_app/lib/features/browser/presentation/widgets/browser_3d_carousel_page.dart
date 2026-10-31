// QUÉ: Página con transformación tridimensional para el carrusel de pestañas.
// CÓMO: Aplica escala y opacidad suave mediante Matrix4 sin oscurecer las vistas con velos negros.
// POR QUÉ: Permite previsualizar pestañas contiguas con sus colores y contenido web real (< 70 líneas).

import 'package:flutter/material.dart';

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
      final hasMetrics =
          controller.hasClients && controller.position.haveDimensions;
      final distance =
          ((hasMetrics ? controller.page : null) ?? currentPage.toDouble()) -
          index;
      final scale = (1.0 - (distance.abs() * 0.10)).clamp(0.88, 1.0);
      final translateY = (distance.abs() * 12.0).clamp(0.0, 20.0);
      final opacity = (1.0 - (distance.abs() * 0.18)).clamp(0.78, 1.0);
      final isCurrent = index == currentPage;

      Widget card = IgnorePointer(
        ignoring: !isCurrent,
        child: Opacity(
          opacity: opacity,
          child: pageChild,
        ),
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
