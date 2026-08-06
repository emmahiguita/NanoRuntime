import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// ── Typography Tokens (Inter — misma familia que el resto de la app) ──
/// Reemplaza los `TextStyle(...)` crudos (Roboto por defecto) por una
/// escala tipográfica consistente y profesional. Todos los estilos son
/// funciones: reciben color porque dependen del tema activo.
class NanoType {
  NanoType._();

  // Escala base — una sola fuente, un solo peso por nivel.
  static TextStyle display(Color c) => GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: -0.5, color: c, height: 1.2);
  static TextStyle title(Color c) => GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: c, height: 1.3);
  static TextStyle subtitle(Color c) => GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: c, height: 1.3);
  static TextStyle body(Color c) => GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w400, color: c, height: 1.4);
  static TextStyle caption(Color c) => GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w400, color: c, height: 1.3);
  static TextStyle label(Color c) => GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: c, height: 1.2);
  static TextStyle overline(Color c) => GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 0.6, color: c, height: 1.2);
}

/// ── Icon Tokens ──
/// Escala única de tamaños de icono: elimina valores sueltos (8, 14, 18,
/// 32, 56) y fija una jerarquía semántica de 5 niveles.
class NanoIcons {
  NanoIcons._();

  static const double tiny = 12;   // adornos / estados (dot, badges)
  static const double small = 16;  // acciones secundarias inline
  static const double medium = 20; // acciones primarias (botones, chips)
  static const double large = 32;  // encabezados de sección
  static const double hero = 56;   // estados vacíos / empty states
}
