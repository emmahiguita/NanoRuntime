import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

// =============================================================
// NANO MOTION SYSTEM — MATERIAL 3 EXPRESSIVE & OPTICAL GLASS
// =============================================================

/// Tokens de duración universales del sistema de movimiento NanoAI.
abstract final class NanoMotionDurations {
  /// Respuestas inmediatas / toggles / micro-feedbacks: 80–100ms
  static const Duration instant = Duration(milliseconds: 90);

  /// Respuesta táctil al presionar (touch down / up): 110–140ms
  static const Duration press = Duration(milliseconds: 120);

  /// Micro-interacciones / hover / focus / badges: 160–190ms
  static const Duration quick = Duration(milliseconds: 180);

  /// Transiciones estándar de UI / tabs / dropdowns / cards: 220–280ms
  static const Duration standard = Duration(milliseconds: 250);

  /// Transiciones enfáticas / expansiones / layouts: 320–420ms
  static const Duration emphasized = Duration(milliseconds: 360);

  /// Navegación primaria entre pantallas / glass morph: 420–560ms
  static const Duration navigation = Duration(milliseconds: 480);

  /// Hero flights / morphing complejo de contenedores: 480–620ms
  static const Duration hero = Duration(milliseconds: 520);

  /// Ciclos ambientales lentos de reflexión óptica: 8–14s
  static const Duration ambient = Duration(seconds: 10);
}

/// Curvas de aceleración y física de amortiguamiento M3 Expressive.
abstract final class NanoMotionCurves {
  /// Curva enfática principal (Snappy takeoff + soft landing)
  static const Curve emphasized = Cubic(0.20, 0.00, 0.00, 1.00);

  /// Curva de desaceleración suave para entradas y aperturas
  static const Curve standardDecel = Cubic(0.00, 0.00, 0.20, 1.00);

  /// Curva de aceleración para salidas y cierres
  static const Curve standardAccel = Cubic(0.40, 0.00, 1.00, 1.00);

  /// Curva de respuesta táctil al presionar
  static const Curve press = Cubic(0.15, 0.85, 0.35, 1.00);

  /// Curva elástica amortiguada (vidrio pesado, no rebote infantil)
  static const Curve glassSpring = Cubic(0.18, 0.90, 0.22, 1.00);

  /// Desplazamiento lineal para gradientes y shaders
  static const Curve linear = Curves.linear;
}

/// Configuraciones de Spring Simulation para física natural.
abstract final class NanoSprings {
  /// Spring para superficies de cristal interactivo (amortiguamiento crítico)
  static const SpringDescription glass = SpringDescription(
    mass: 1.0,
    stiffness: 340.0,
    damping: 30.0,
  );

  /// Spring para el carrusel y deslizamientos espaciales
  static const SpringDescription carousel = SpringDescription(
    mass: 1.0,
    stiffness: 280.0,
    damping: 26.0,
  );

  /// Spring para BottomSheets y modales
  static const SpringDescription sheet = SpringDescription(
    mass: 1.2,
    stiffness: 260.0,
    damping: 25.0,
  );

  /// Crea una simulación de resorte desde [start] a [end] con [velocity]
  static SpringSimulation createSimulation({
    required double start,
    required double end,
    double velocity = 0.0,
    SpringDescription spring = glass,
  }) {
    return SpringSimulation(spring, start, end, velocity);
  }
}

/// Constantes de respuesta física al tacto en superficies ópticas.
abstract final class NanoPressResponse {
  /// Escala al presionar (touch down)
  static const double scaleDown = 0.985;

  /// Elevación visual Z reducida
  static const double translateZOffset = -2.0;

  /// Reducción de sombra durante la compresión
  static const double shadowScale = 0.85;

  /// Desplazamiento máximo de paralaje en grados
  static const double maxParallaxRotateX = 1.2 * (3.141592653589793 / 180.0);
  static const double maxParallaxRotateY = 1.8 * (3.141592653589793 / 180.0);
}

/// Helper para verificar accesibilidad y reducción de movimiento.
class NanoMotion {
  static bool reduceMotion(BuildContext context) {
    return MediaQuery.disableAnimationsOf(context);
  }

  /// Retorna la duración adaptada considerando accesibilidad
  static Duration adapt(BuildContext context, Duration duration) {
    return reduceMotion(context) ? Duration.zero : duration;
  }
}
