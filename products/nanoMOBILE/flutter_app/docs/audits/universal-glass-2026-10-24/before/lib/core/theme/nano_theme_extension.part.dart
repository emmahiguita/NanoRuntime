part of 'design_tokens.dart';

/// Extensión de tema para la paleta semántica y óptica de Nano AI.
///
/// - QUÉ HACE: Inyecta los tokens [NanoColors] y propiedades de blur en el [ThemeData] de Flutter.
/// - CÓMO FUNCIONA: Implementa [ThemeExtension.lerp] delegando la interpolación en [_LerpedNanoColors].
///   Permite acceder a los colores en cualquier punto del árbol mediante [NanoThemeExtension.of(context)].
/// - POR QUÉ: Cumple con la arquitectura de Flutter para temas personalizados sin ensuciar [ColorScheme].
class NanoThemeExtension extends ThemeExtension<NanoThemeExtension> {
  final NanoColors colors;
  final bool glassEnabled;
  final double glassOpacity;
  final double glassClarity;
  final double glassBlur;

  NanoThemeExtension({
    required this.colors,
    this.glassEnabled = true,
    this.glassOpacity = 0.70,
    this.glassClarity = 0.85,
    this.glassBlur = 18.0,
  });

  @override
  ThemeExtension<NanoThemeExtension> copyWith({
    NanoColors? colors,
    bool? glassEnabled,
    double? glassOpacity,
    double? glassClarity,
    double? glassBlur,
  }) =>
      NanoThemeExtension(
        colors: colors ?? this.colors,
        glassEnabled: glassEnabled ?? this.glassEnabled,
        glassOpacity: glassOpacity ?? this.glassOpacity,
        glassClarity: glassClarity ?? this.glassClarity,
        glassBlur: glassBlur ?? this.glassBlur,
      );

  @override
  ThemeExtension<NanoThemeExtension> lerp(
    ThemeExtension<NanoThemeExtension>? other,
    double t,
  ) {
    if (other is! NanoThemeExtension) return this;
    return NanoThemeExtension(
      colors: _LerpedNanoColors(a: colors, b: other.colors, t: t),
      glassEnabled: other.glassEnabled,
      glassOpacity: glassOpacity + (other.glassOpacity - glassOpacity) * t,
      glassClarity: glassClarity + (other.glassClarity - glassClarity) * t,
      glassBlur: glassBlur + (other.glassBlur - glassBlur) * t,
    );
  }

  static NanoThemeExtension of(BuildContext context) =>
      Theme.of(context).extension<NanoThemeExtension>() ??
      (Theme.of(context).brightness == Brightness.dark
          ? NanoThemeExtension(colors: const NanoDarkColors())
          : NanoThemeExtension(colors: const NanoLightColors()));

  static NanoThemeExtension? maybeOf(BuildContext context) =>
      Theme.of(context).extension<NanoThemeExtension>();
}

/// Helper para contraste de texto WCAG AA (≥4.5:1) sobre fondos variables.
///
/// - QUÉ HACE: Asegura que los colores de texto derivados de acentos pastel sean legibles.
/// - CÓMO FUNCIONA: Calcula luminancia relativa y oscurece/aclara progresivamente el acento
///   hasta superar el ratio de contraste 4.5:1 exigido por WCAG AA.
/// - POR QUÉ: Elimina textos opacos, lavados o invisibles en badges, chips y etiquetas.
abstract final class NanoTextColors {
  /// Contraste WCAG entre dos colores opacos (rango 1.0 a 21.0).
  static double _contrast(Color a, Color b) {
    final la = a.computeLuminance();
    final lb = b.computeLuminance();
    final lighter = la > lb ? la : lb;
    final darker = la > lb ? lb : la;
    return (lighter + 0.05) / (darker + 0.05);
  }

  /// Devuelve [accent] optimizado para lectura sobre [colors.backgroundPrimary].
  static Color forText(Color accent, NanoColors colors) {
    final bg = colors.backgroundPrimary;
    if (_contrast(accent, bg) >= 4.5) return accent;
    final target = colors is NanoDarkColors
        ? const Color(0xFFFFFFFF)
        : const Color(0xFF0B1220);
    var t = 0.15;
    while (t < 1.0) {
      final candidate = Color.lerp(accent, target, t)!;
      if (_contrast(candidate, bg) >= 4.5) return candidate;
      t += 0.15;
    }
    return target;
  }
}
