import 'package:flutter/material.dart';

/// Tokens de diseño visual para la barra de navegación cósmica de Nano AI.
///
/// Diseñados para replicar con máxima fidelidad la estética glassmorphism
/// cósmica de la referencia: azules profundos, acentos eléctricos, resplandores
/// de neón cian y violeta, y soporte completo para modo oscuro y claro.
@immutable
class NanoNavTokens {
  const NanoNavTokens._();

  // Acentos de marca cósmicos
  static const accentBlue = Color(0xFF2A7FFF);
  static const electricBlue = Color(0xFF42B7FF);
  static const cyan = Color(0xFF5CE7FF);
  static const neonGreen = Color(0xFF00FF9D);
  static const violet = Color(0xFF755DFF);
  static const indigo = Color(0xFF304CFF);

  // Paleta oscura (Cosmic Dark sampled from reference)
  static const darkBackdrop = Color(0xFF030B20);
  static const darkSurface = Color(0xE9102147);
  static const darkSurfaceDeep = Color(0xEF07152F);
  static const darkText = Color(0xFFF5F8FF);
  static const darkTextMuted = Color(0xFFB9C6E5);
  static const darkStroke = Color(0x6689B7FF);
  static const darkSeparator = Color(0x2A9EBEFF);

  // Paleta clara (Cosmic Light)
  static const lightBackdrop = Color(0xFFF3F8FF);
  static const lightSurface = Color(0xEFFFFFFF);
  static const lightSurfaceAlt = Color(0xDDEAF2FF);
  static const lightText = Color(0xFF0A2550);
  static const lightTextMuted = Color(0xFF55709D);
  static const lightStroke = Color(0xBFFFFFFF);
  static const lightSeparator = Color(0x26647FAF);

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

  // Gradiente orbital de acento activo
  static const activeGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF5BE8FF), Color(0xFF2A7FFF), Color(0xFF755DFF)],
    stops: [0.0, 0.48, 1.0],
  );

  // Gradiente del botón de envío / flecha
  static const sendButtonGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF3B82F6), Color(0xFF6366F1), Color(0xFF4F46E5)],
    stops: [0.0, 0.55, 1.0],
  );

  // Gradiente exterior de la carcasa (shell) en modo oscuro - Glass Cósmico iOS
  static const shellGradientDark = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xA5183868), // azul zafiro translúcido
      Color(0x95122850), // azul profundo translúcido
      Color(0x850C1D3E), // azul noche translúcido
    ],
    stops: [0.0, 0.50, 1.0],
  );

  // Gradiente exterior de la carcasa en modo claro - Glass iOS Blanco Puro
  static const shellGradientLight = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xCCFFFFFF),
      Color(0xB5F4F8FF),
      Color(0x9EE8F0FF),
    ],
    stops: [0.0, 0.55, 1.0],
  );

  static LinearGradient shell(Brightness b) =>
      b == Brightness.dark ? shellGradientDark : shellGradientLight;
}
