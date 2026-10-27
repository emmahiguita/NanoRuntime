// model_3d_flip_flight.dart — Vuelo Hero con transición 3D Card Flip en el eje Y.
// QUÉ HACE: Transforma la tarjeta durante el desprendimiento elevándola con rotación 3D de 70-80° y retorno a 0°.
// CÓMO FUNCIONA: Aplica matriz m44 con perspectiva física, rotación sinusoidal y crossfade de contenido.
// POR QUÉ: Permite el desprendimiento cinematográfico de la tarjeta hacia la ventana flotante (< 90 líneas).
library;

import 'dart:math' as math;
import 'package:flutter/material.dart';

Widget model3DCardFlipFlight(
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
      // Curva Ease In-Out pronunciada
      final double t = Curves.easeInOutCubicEmphasized.transform(rawT);

      // Rotación en el eje Y: de 0° sube hasta ~75° en el punto medio (sinusoidal) y regresa a 0°
      final double directionMultiplier =
          direction == HeroFlightDirection.push ? 1.0 : -1.0;
      final double rotationY =
          math.sin(math.pi * t) * (math.pi / 2.35) * directionMultiplier;

      // Micro-punch de escala óptica durante el vuelo
      final double flightScale = 1.0 + math.sin(math.pi * t) * 0.035;

      // Morfismo progresivo de contenido entre anverso original y ventana flotante
      final double progress = direction == HeroFlightDirection.push ? t : 1.0 - t;
      final double morphProgress =
          ((progress - 0.25) / 0.50).clamp(0.0, 1.0).toDouble();

      return Transform.scale(
        scale: flightScale,
        child: Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, -0.00135)
            ..rotateY(rotationY),
          child: Stack(
            clipBehavior: Clip.none,
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
      );
    },
  );
}
