import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Hinge de perspectiva 3D durante el vuelo de Hero (SRP).
///
/// Mientras la tarjeta vuela entre el carrusel y la pantalla modal,
/// se inclina temporalmente en el eje Y (alcanzando su punto máximo en la mitad del arco)
/// y regresa con elegancia a 0° al aterrizar.
Widget perspectiveHeroFlight(
  BuildContext flightContext,
  Animation<double> animation,
  HeroFlightDirection direction,
  BuildContext fromHeroContext,
  BuildContext toHeroContext,
) {
  final Hero fromHero = fromHeroContext.widget as Hero;
  final Hero toHero = toHeroContext.widget as Hero;
  final Widget fromChild = fromHero.child;
  final Widget toChild = toHero.child;

  return AnimatedBuilder(
    animation: animation,
    builder: (context, _) {
      final double rawT = animation.value;
      final double t = Curves.easeInOutCubicEmphasized.transform(rawT);

      // Inclinación sinusoidal: 0° -> 17° -> 0°
      final double directionMultiplier =
          direction == HeroFlightDirection.push ? 1.0 : -1.0;
      final double rotationY =
          math.sin(math.pi * t) * 0.30 * directionMultiplier;

      // Micro-punch de escala mientras viaja por el aire
      final double flightScale = 1.0 + math.sin(math.pi * t) * 0.028;

      // Morfismo progresivo de contenido (crossfade suave)
      final double morphProgress =
          ((t - 0.20) / 0.60).clamp(0.0, 1.0).toDouble();

      return Transform.scale(
        scale: flightScale,
        child: Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.00115)
            ..rotateY(rotationY),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Opacity(
                  opacity: (1.0 - morphProgress).clamp(0.0, 1.0),
                  child: fromChild,
                ),
                Opacity(
                  opacity: morphProgress.clamp(0.0, 1.0),
                  child: toChild,
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
