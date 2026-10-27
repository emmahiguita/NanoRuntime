part of 'design_tokens.dart';

/// Tokens de espaciado basados en la grilla matemática de 8dp.
///
/// - QUÉ HACE: Estandariza los márgenes, paddings y distancias entre elementos.
/// - CÓMO FUNCIONA: Multiplica la unidad base (8dp) para generar escalas proporcionales.
/// - POR QUÉ: Elimina números mágicos y asegura ritmo vertical y horizontal consistente.
class NanoSpacing {
  const NanoSpacing._();

  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
  static const xxxl = 48.0;
  static const statCardHeight = 100.0;
  static const minTouch =
      44.0; // Tamaño mínimo de interacción táctil iOS/Android
}

/// Curvas de animación cinemáticas estándar de Nano AI.
///
/// - QUÉ HACE: Define las curvas de aceleración y desaceleración para transiciones y microinteracciones.
/// - CÓMO FUNCIONA: Utiliza curvas cúbicas suaves ([Curves.easeOutCubic] y [Curves.easeInOutCubic]).
/// - POR QUÉ: Aporta naturalidad física sin sensación de rigidez ni saltos bruscos.
class NanoCurves {
  const NanoCurves._();

  static const easeOut = Curves.easeOutCubic;
  static const easeInOut = Curves.easeInOutCubic;
}

/// Radios numéricos escalonados para bordes redondeados.
///
/// - QUÉ HACE: Define valores escalares de radio de curvatura.
/// - CÓMO FUNCIONA: Ofrece radios discretos de 12, 18, 26, 34 y 40dp.
/// - POR QUÉ: Mantiene armonía geométrica con las pautas de iOS Human Interface.
class NanoRadius {
  const NanoRadius._();

  static const double small = 12.0;
  static const double medium = 18.0;
  static const double large = 26.0;
  static const double xLarge = 34.0;
  static const double hero = 40.0;
}

/// Tokens de formas y contornos redondeados ([BorderRadius]).
///
/// - QUÉ HACE: Provee instancias [BorderRadius] precalculadas e inmutables para tarjetas,
///   diálogos, botones y burbujas de mensajería.
/// - CÓMO FUNCIONA: Reutiliza instancias const en memoria, evitando asignaciones repetitivas en cada frame.
/// - POR QUÉ: Maximiza rendimiento del garbage collector de Flutter.
class NanoShapes {
  const NanoShapes._();

  static const small = BorderRadius.all(Radius.circular(12));
  static const medium = BorderRadius.all(Radius.circular(18));
  static const large = BorderRadius.all(Radius.circular(24));
  static const extraLarge = BorderRadius.all(Radius.circular(32));
  static const hero = BorderRadius.all(Radius.circular(40));
  static const full = BorderRadius.all(Radius.circular(100));

  static const userBubble = BorderRadius.only(
    topLeft: Radius.circular(24),
    topRight: Radius.circular(24),
    bottomLeft: Radius.circular(24),
    bottomRight: Radius.circular(6),
  );

  static const aiBubble = BorderRadius.only(
    topLeft: Radius.circular(24),
    topRight: Radius.circular(24),
    bottomLeft: Radius.circular(6),
    bottomRight: Radius.circular(24),
  );
}
