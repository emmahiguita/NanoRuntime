part of 'design_tokens.dart';

/// Clasifica el material por su luminancia real. Gris espacial implementa
/// NanoColors, no hereda NanoDarkColors: comprobar el tipo lo trataba como claro.
/// También funciona durante la interpolación animada entre dos paletas.
abstract final class NanoPaletteBrightness {
  /// Elige el texto de mayor contraste sobre un acento opaco. Evita heredar
  /// colores claros/oscuros predeterminados que pertenecen a otra paleta.
  static Color foreground(Color background) {
    final luminance = background.computeLuminance();
    final blackContrast = (luminance + .05) / .05;
    final whiteContrast = 1.05 / (luminance + .05);
    return blackContrast >= whiteContrast ? Colors.black : Colors.white;
  }

  /// Reconoce el fondo negro tambi?n durante la interpolaci?n del tema.
  /// El umbral mantiene separada la paleta gris espacial.
  static bool isBlack(NanoColors colors) =>
      colors.backgroundPrimary.computeLuminance() < 0.001;

  static bool isDark(NanoColors colors) =>
      ThemeData.estimateBrightnessForColor(colors.surface) == Brightness.dark;
}
