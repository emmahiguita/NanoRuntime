import 'package:flutter/material.dart';

/// â”€â”€ Typography Tokens (Inter â€” misma familia que el resto de la app) â”€â”€
/// Reemplaza los `TextStyle(...)` crudos (Roboto por defecto) por una
/// escala tipogrÃ¡fica consistente y profesional. Todos los estilos son
/// funciones: reciben color porque dependen del tema activo.
class NanoType {
  NanoType._();

  // Escala base â€” una sola fuente, un solo peso por nivel.
  static TextStyle display(Color c) => TextStyle(fontFamily: 'Inter', fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: -0.5, color: c, height: 1.2);
  static TextStyle title(Color c) => TextStyle(fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.w600, color: c, height: 1.3);
  static TextStyle subtitle(Color c) => TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.w500, color: c, height: 1.3);
  static TextStyle body(Color c) => TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w400, color: c, height: 1.4);
  static TextStyle caption(Color c) => TextStyle(fontFamily: 'Inter', fontSize: 11, fontWeight: FontWeight.w400, color: c, height: 1.3);
  static TextStyle label(Color c) => TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w500, color: c, height: 1.2);
  static TextStyle overline(Color c) => TextStyle(fontFamily: 'Inter', fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 0.6, color: c, height: 1.2);
  /// Números grandes para dashboard / métricas (RAM, temp, batería, etc.).
  static TextStyle metric(Color c) => TextStyle(fontFamily: 'Inter', fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -0.5, color: c, height: 1.2);
}

/// â”€â”€ Icon Tokens â”€â”€
/// Escala Ãºnica de tamaÃ±os de icono: elimina valores sueltos (8, 14, 18,
/// 32, 56) y fija una jerarquÃ­a semÃ¡ntica de 5 niveles.
class NanoIcons {
  NanoIcons._();

  static const double tiny = 12;   // adornos / estados (dot, badges)
  static const double small = 16;  // acciones secundarias inline
  static const double medium = 20; // acciones primarias (botones, chips)
  static const double large = 32;  // encabezados de secciÃ³n
  static const double hero = 56;   // estados vacÃ­os / empty states
}
