part of 'design_tokens.dart';

/// Sistema de sombras ópticas multi-capa (NanoShadows).
///
/// - QUÉ HACE: Genera elevación visual física mediante combinaciones de sombras difusas,
///   de contacto y resplandores ambientales.
/// - CÓMO FUNCIONA: Adapta la opacidad y dispersión de las capas de [BoxShadow] según
///   el brillo del tema (isDark) y el factor de profundidad paramétrico [depth].
/// - POR QUÉ: Evita sombras toscas de una sola capa, emulando la física de la luz natural
///   para dar jerarquía espacial sin saturar la GPU.
abstract final class NanoShadows {
  /// Sombra ambiental óptica (Multi-capa: difusa + contacto + acento sutil)
  static List<BoxShadow> ambient(
    NanoColors colors, {
    double depth = 1.0,
    Color? accent,
  }) {
    final isDark = colors is NanoDarkColors;
    final shadowBase = isDark
        ? const Color(0xFF000000)
        : const Color(0xFF7F9AB5);
    final primaryOpacity = isDark
        ? (0.28 + (0.22 * depth)).clamp(0.0, 0.70)
        : (0.06 + (0.06 * depth)).clamp(0.0, 0.20);

    return [
      // Capa 1: Sombra difusa principal (iluminación ambiental)
      BoxShadow(
        color: shadowBase.withValues(alpha: primaryOpacity),
        blurRadius: 24.0 + (18.0 * depth),
        offset: Offset(0, 10.0 * depth),
        spreadRadius: isDark ? 0.0 : -2.0,
      ),
      // Capa 2: Sombra de contacto / proximidad
      BoxShadow(
        color: shadowBase.withValues(alpha: isDark ? 0.20 : 0.04),
        blurRadius: 6.0 + (4.0 * depth),
        offset: Offset(0, 2.0 * depth),
      ),
      // Capa 3: Resplandor de acento opcional (solo modo oscuro)
      if (isDark && accent != null)
        BoxShadow(
          color: accent.withValues(alpha: 0.04 * depth.clamp(0.5, 1.5)),
          blurRadius: 28.0 * depth,
          spreadRadius: -4.0,
        ),
    ];
  }

  /// Sombra para botones y controles interactivos
  static List<BoxShadow> control(
    NanoColors colors, {
    bool isPressed = false,
    Color? accent,
  }) {
    if (isPressed) {
      return [
        BoxShadow(
          color: (colors is NanoDarkColors
                  ? const Color(0xFF000000)
                  : const Color(0xFF7F9AB5))
              .withValues(alpha: 0.08),
          blurRadius: 4,
          offset: const Offset(0, 2),
        ),
      ];
    }
    return ambient(colors, depth: 0.6, accent: accent);
  }

  static List<BoxShadow> card(NanoColors c) => [
    BoxShadow(
      color: c is NanoDarkColors
          ? const Color(0xFF000000).withValues(alpha: 0.3)
          : const Color(0xFF7F9AB5).withValues(alpha: 0.08),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
    if (c is! NanoDarkColors)
      BoxShadow(
        color: const Color(0xFF7F9AB5).withValues(alpha: 0.04),
        blurRadius: 2,
        offset: const Offset(0, 1),
      ),
  ];

  static List<BoxShadow> elevated(NanoColors c) => [
    BoxShadow(
      color: c is NanoDarkColors
          ? const Color(0xFF000000).withValues(alpha: 0.4)
          : const Color(0xFF7F9AB5).withValues(alpha: 0.12),
      blurRadius: 20,
      offset: const Offset(0, 8),
    ),
    if (c is! NanoDarkColors)
      BoxShadow(
        color: const Color(0xFF7F9AB5).withValues(alpha: 0.06),
        blurRadius: 4,
        offset: const Offset(0, 2),
      ),
  ];

  static List<BoxShadow> glow(NanoColors c, Color color) => [
    BoxShadow(
      color: color.withValues(alpha: c is NanoDarkColors ? 0.35 : 0.20),
      blurRadius: 16,
      spreadRadius: 1,
    ),
  ];

  static List<BoxShadow> fab(NanoColors c) => [
    BoxShadow(
      color: c is NanoDarkColors
          ? const Color(0xFF000000).withValues(alpha: 0.5)
          : const Color(0xFF7F9AB5).withValues(alpha: 0.16),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
    if (c is! NanoDarkColors)
      BoxShadow(
        color: const Color(0xFF7F9AB5).withValues(alpha: 0.08),
        blurRadius: 6,
        offset: const Offset(0, 2),
      ),
  ];

  static List<BoxShadow> highlight(NanoColors c) => [
    if (c is! NanoDarkColors)
      BoxShadow(
        color: const Color(0xFF0284C7).withValues(alpha: 0.15),
        blurRadius: 8,
        offset: const Offset(0, 2),
      ),
  ];

  static List<BoxShadow> glass(NanoColors c) => ambient(c, depth: 0.8);
  static List<BoxShadow> glassElevated(NanoColors c) => ambient(c, depth: 1.5);
}
