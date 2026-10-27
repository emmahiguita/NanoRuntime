// QUÉ: presenta un logotipo original con una única animación de entrada.
// CÓMO: lee un asset local, ajusta su resolución y gira 360° durante 900 ms.
// POR QUÉ: Gemma y Qwen comparten movimiento y accesibilidad sin duplicar lógica.
import 'dart:math' as math;
import 'package:flutter/material.dart';

class OfficialModelBrandIcon extends StatelessWidget {
  const OfficialModelBrandIcon({
    super.key,
    required this.asset,
    required this.brand,
    this.size = 38,
    this.animate = true,
  });

  final String asset;
  final String brand;
  final double size;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.maybeOf(context);
    final reduceMotion =
        !animate ||
        (media?.disableAnimations ?? false) ||
        (media?.accessibleNavigation ?? false);
    final image = Semantics(
      image: true,
      label: 'Logotipo oficial de $brand',
      child: Image.asset(
        asset,
        width: size,
        height: size,
        fit: BoxFit.contain,
        excludeFromSemantics: true,
        cacheWidth: (size * (media?.devicePixelRatio ?? 1)).ceil(),
        filterQuality: FilterQuality.medium,
      ),
    );
    // Cambiar a movimiento reducido desmonta inmediatamente el animador.
    if (reduceMotion) return image;
    // Sin repeat() ni temporizadores. Flutter libera el controlador implícito.
    return RepaintBoundary(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeOutCubic,
        child: image,
        builder: (context, value, child) =>
            Transform.rotate(angle: (1 - value) * -2 * math.pi, child: child),
      ),
    );
  }
}
