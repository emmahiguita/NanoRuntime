import 'package:flutter/material.dart';

/// â”€â”€ Typography Tokens (Inter — misma familia que el resto de la app) â”€â”€
/// Reemplaza los `TextStyle(...)` crudos (Roboto por defecto) por una
/// escala tipográfica consistente y profesional. Todos los estilos son
/// funciones: reciben color porque dependen del tema activo.
class NanoType {
  NanoType._();

  // Escala base — Inter y JetBrainsMono alineadas a Nano Design System v1.
  static TextStyle display(Color c) => TextStyle(
    fontFamily: 'Inter',
    fontSize: 32,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.60,
    color: c,
    height: 38 / 32,
  );

  static TextStyle largeTitle(Color c) => TextStyle(
    fontFamily: 'Inter',
    fontSize: 28,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.40,
    color: c,
    height: 34 / 28,
  );

  static TextStyle title(Color c) => TextStyle(
    fontFamily: 'Inter',
    fontSize: 22,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.25,
    color: c,
    height: 28 / 22,
  );

  static TextStyle headline(Color c) => TextStyle(
    fontFamily: 'Inter',
    fontSize: 18,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.10,
    color: c,
    height: 24 / 18,
  );

  static TextStyle body(Color c) => TextStyle(
    fontFamily: 'Inter',
    fontSize: 16,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.0,
    color: c,
    height: 24 / 16,
  );

  static TextStyle bodySecondary(Color c) => TextStyle(
    fontFamily: 'Inter',
    fontSize: 15,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.0,
    color: c,
    height: 22 / 15,
  );

  static TextStyle subtitle(Color c) => TextStyle(
    fontFamily: 'Inter',
    fontSize: 14,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.05,
    color: c,
    height: 20 / 14,
  );

  static TextStyle callout(Color c) => TextStyle(
    fontFamily: 'Inter',
    fontSize: 14,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.10,
    color: c,
    height: 20 / 14,
  );

  static TextStyle label(Color c) => TextStyle(
    fontFamily: 'Inter',
    fontSize: 13,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.20,
    color: c,
    height: 18 / 13,
  );

  static TextStyle caption(Color c) => TextStyle(
    fontFamily: 'Inter',
    fontSize: 12,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.20,
    color: c,
    height: 16 / 12,
  );

  static TextStyle micro(Color c) => TextStyle(
    fontFamily: 'Inter',
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.30,
    color: c,
    height: 14 / 11,
  );

  static TextStyle overline(Color c) => TextStyle(
    fontFamily: 'Inter',
    fontSize: 10,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.60,
    color: c,
    height: 1.2,
  );

  static TextStyle terminal(Color c) => TextStyle(
    fontFamily: 'JetBrainsMono',
    fontSize: 14,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.0,
    color: c,
    height: 20 / 14,
  );

  /// Números grandes para dashboard / métricas (RAM, temp, batería, etc.).
  static TextStyle metric(Color c) => TextStyle(
    fontFamily: 'Inter',
    fontSize: 20,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    color: c,
    height: 1.2,
  );
}

/// â”€â”€ Icon Tokens â”€â”€
/// Escala única de tamaños de icono: elimina valores sueltos (8, 14, 18,
/// 32, 56) y fija una jerarquía semántica de 5 niveles.
class NanoIcons {
  NanoIcons._();

  static const double tiny = 12; // adornos / estados (dot, badges)
  static const double small = 16; // acciones secundarias inline
  static const double medium = 20; // acciones primarias (botones, chips)
  static const double large = 32; // encabezados de sección
  static const double hero = 56; // estados vacíos / empty states
}
