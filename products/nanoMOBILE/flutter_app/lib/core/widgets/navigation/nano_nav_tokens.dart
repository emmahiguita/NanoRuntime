import 'package:flutter/material.dart';

/// Tokens de diseño visual para la barra de navegación cósmica de Nano AI.
///
/// Modo oscuro → acento ámbar/naranja noble. Modo claro → azul iOS profesional.
@immutable
class NanoNavTokens {
  const NanoNavTokens._();

  // Acentos de marca Nano
  static const accentAmber = Color(0xFFFF8C2A); // Modo oscuro
  static const accentBlue = Color(0xFF1D6FE8);  // Modo claro iOS
  static const electricBlue = Color(0xFF2563EB);
  static const neonGreen = Color(0xFF10B981);
  static const violet = Color(0xFF818CF8);
  static const indigo = Color(0xFF6366F1);

  // Paleta oscura (Cosmic Dark - alta fidelidad y contraste)
  static const darkBackdrop = Color(0xFF020711);
  static const darkSurface = Color(0xE90F172A);
  static const darkSurfaceDeep = Color(0xEF020711);
  static const darkText = Color(0xFFF8FAFC);
  static const darkTextMuted = Color(0xFFA8B3C2);
  static const darkStroke = Color(0x33FFFFFF);
  static const darkSeparator = Color(0x26FFFFFF);

  // Paleta clara (Nano Light - superficies limpias y texto nítido)
  static const lightBackdrop = Color(0xFFF8FAFC);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightSurfaceAlt = Color(0xFFF1F5F9);
  static const lightText = Color(0xFF0F172A);
  static const lightTextMuted = Color(0xFF475569);
  static const lightStroke = Color(0xFFE2E8F0);
  static const lightSeparator = Color(0x33CBD5E1);

  static Color text(Brightness b) =>
      b == Brightness.dark ? darkText : lightText;

  static Color textMuted(Brightness b) =>
      b == Brightness.dark ? darkTextMuted : lightTextMuted;

  static Color surface(Brightness b) =>
      b == Brightness.dark ? darkSurface : lightSurface;

  static Color stroke(Brightness b) =>
      b == Brightness.dark ? darkStroke : lightStroke;

  static Color separator(Brightness b) =>
      b == Brightness.dark ? darkSeparator : lightSeparator;

  /// Retorna el color de acento activo según el brillo del contexto.
  static Color activeAccent(Brightness b) =>
      b == Brightness.dark ? accentAmber : accentBlue;

  // Gradiente orbital de acento activo — ámbar en oscuro, azul iOS en claro
  static const activeGradientDark = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFF8C2A), Color(0xFFFF6D00), Color(0xFFE65100)],
    stops: [0.0, 0.50, 1.0],
  );

  static const activeGradientLight = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF60A5FA), Color(0xFF1D6FE8), Color(0xFF1E40AF)],
    stops: [0.0, 0.50, 1.0],
  );

  static LinearGradient activeGradient(Brightness b) =>
      b == Brightness.dark ? activeGradientDark : activeGradientLight;

  // Gradiente del botón de envío
  static const sendButtonGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFF8C2A), Color(0xFFFF6D00), Color(0xFFE65100)],
    stops: [0.0, 0.50, 1.0],
  );

  // Gradiente exterior de la carcasa (shell) en modo oscuro - Glass Cósmico iOS
  static const shellGradientDark = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0x66183868),
      Color(0x58122850),
      Color(0x4D0C1D3E),
    ],
    stops: [0.0, 0.50, 1.0],
  );

  // Gradiente exterior de la carcasa en modo claro — Glass Blanco + tinte azul
  static const shellGradientLight = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xB8FFFFFF),
      Color(0x9CF0F7FF),
      Color(0x82E0EEFF),
    ],
    stops: [0.0, 0.55, 1.0],
  );

  static LinearGradient shell(Brightness b) =>
      b == Brightness.dark ? shellGradientDark : shellGradientLight;
}
