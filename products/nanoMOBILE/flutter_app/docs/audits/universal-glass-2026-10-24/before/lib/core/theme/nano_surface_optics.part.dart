part of 'design_tokens.dart';

/// Organización de líneas, biseles y bordes perimetrales (NanoBorders).
///
/// - QUÉ HACE: Crea gradientes de borde perimetral y biseles especulares.
/// - CÓMO FUNCIONA: Combina [SweepGradient] y [LinearGradient] con reflexiones
///   calculadas sobre [NanoColors.borderPrimaryColor] y [NanoColors.silverReflection].
/// - POR QUÉ: Dota a las tarjetas y paneles de bordes con refracción cromática viva.
abstract final class NanoBorders {
  /// Borde metálico perimetral con refracción cromática continua.
  static Gradient metallicRim(
    NanoColors colors, {
    Color? accent,
    double refractionIntensity = 1.0,
  }) {
    final isDark = colors is NanoDarkColors;
    final accentCol = accent ?? colors.primary;
    final accentOpacity = (isDark ? 0.25 : 0.35) * refractionIntensity;

    return SweepGradient(
      center: Alignment.center,
      startAngle: 0.0,
      endAngle: 6.28318,
      colors: [
        colors.borderPrimaryColor,
        colors.borderSecondaryColor,
        accentCol.withValues(alpha: accentOpacity.clamp(0.0, 1.0)),
        colors.silverReflection.withValues(alpha: isDark ? 0.18 : 0.40),
        colors.borderPrimaryColor,
      ],
      stops: const [0.0, 0.35, 0.60, 0.85, 1.0],
    );
  }

  /// Bisel de luz especular superior-izquierda a inferior-derecha.
  static Gradient specularChamfer(NanoColors colors) {
    final isDark = colors is NanoDarkColors;
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        colors.borderPrimaryColor.withValues(alpha: isDark ? 0.30 : 0.85),
        colors.borderSecondaryColor.withValues(alpha: isDark ? 0.10 : 0.25),
      ],
    );
  }

  /// Borde fino estructural (hairline) de 0.8dp.
  static Border hairline(NanoColors colors, {double opacity = 1.0}) {
    return Border.all(
      color: colors.borderSecondaryColor.withValues(
        alpha: (colors.borderSecondaryColor.a * opacity).clamp(0.0, 1.0),
      ),
      width: 0.8,
    );
  }
}

/// Organización del diseño metálico y texturas procedurales (NanoMetallic).
///
/// - QUÉ HACE: Genera gradientes de titanio pulido y resplandores de Fresnel.
/// - CÓMO FUNCIONA: Usa gradientes radiales y lineales con alfas sutiles para emular aleaciones de aluminio.
/// - POR QUÉ: Brinda aspecto aeroespacial sin recurrir a bitmaps que aumenten el peso del binario.
abstract final class NanoMetallic {
  /// Gradiente de titanio / cromo pulido.
  static Gradient titanium(NanoColors colors) {
    final isDark = colors is NanoDarkColors;
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: isDark
          ? const [
              Color(0xFF182230),
              Color(0xFF0F1722),
              Color(0xFF141D28),
            ]
          : const [
              Color(0xFFFFFFFF),
              Color(0xFFEEF2F6),
              Color(0xFFE2E8F0),
            ],
    );
  }

  /// Resplandor de Fresnel en esquina superior izquierda.
  static Gradient fresnelGlow(NanoColors colors, {double intensity = 1.0}) {
    final isDark = colors is NanoDarkColors;
    final alpha = (isDark ? 0.08 : 0.14) * intensity;
    return RadialGradient(
      center: Alignment.topLeft,
      radius: 1.3,
      colors: [
        colors.pearlReflection.withValues(alpha: alpha.clamp(0.0, 1.0)),
        Colors.transparent,
      ],
    );
  }
}

/// Organización del efecto de cristal óptico (NanoGlass).
///
/// - QUÉ HACE: Genera sustratos de vidrio líquido, reflejos diagonales y tintes de profundidad.
/// - CÓMO FUNCIONA: Apila gradientes lineales y radiales con factores de transparencia calibrados.
/// - POR QUÉ: Emula el material translucido Liquid Glass de iOS con alto rendimiento de dibujado.
abstract final class NanoGlass {
  /// Substrato vítreo con gradiente lineal interno.
  static Gradient substrate(NanoColors colors, {double opacity = 0.60}) {
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        colors.glassPrimary.withValues(alpha: opacity.clamp(0.0, 1.0)),
        colors.glassSecondary.withValues(
          alpha: (opacity * 0.82).clamp(0.0, 1.0),
        ),
        colors.glassGraphite.withValues(
          alpha: (opacity * 0.90).clamp(0.0, 1.0),
        ),
      ],
    );
  }

  /// Tinte de acento radial en esquina inferior.
  static Gradient accentTint(Color accent, {double depth = 1.0}) {
    return RadialGradient(
      center: Alignment.bottomRight,
      radius: 1.4,
      colors: [
        accent.withValues(alpha: (0.05 * depth).clamp(0.0, 0.20)),
        Colors.transparent,
      ],
    );
  }

  /// Haz de brillo especular diagonal.
  static Gradient specularSheen(NanoColors colors, {double intensity = 1.0}) {
    return LinearGradient(
      colors: [
        Colors.transparent,
        colors.iceReflection.withValues(
          alpha: (0.03 * intensity).clamp(0.0, 0.15),
        ),
        colors.pearlReflection.withValues(
          alpha: (0.09 * intensity).clamp(0.0, 0.25),
        ),
        Colors.transparent,
      ],
      stops: const [0.0, 0.45, 0.55, 1.0],
    );
  }
}
