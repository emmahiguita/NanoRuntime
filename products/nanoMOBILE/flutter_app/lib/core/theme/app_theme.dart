import 'package:flutter/material.dart';
import 'design_tokens.dart';
import 'nano_transitions.dart';
part 'app_theme_typography.part.dart';
part 'app_theme_controls.part.dart';
part 'app_theme_surfaces.part.dart';

/// Tema global: la paleta define el brillo, el texto y los controles.
class AppTheme {
  static ThemeData _base(
    NanoColors c, {
    bool glassEnabled = true,
    double glassOpacity = 0.70,
    double glassClarity = 0.85,
    double glassBlur = 18.0,
  }) {
    final isDark = NanoPaletteBrightness.isDark(c);
    final base = ThemeData(
      useMaterial3: true,
      brightness: isDark ? Brightness.dark : Brightness.light,
      colorScheme: isDark
          ? ColorScheme.dark(
              primary: c.primary,
              onPrimary: c.onAccent,
              primaryContainer: c.primaryContainer,
              onPrimaryContainer: c.onPrimaryContainer,
              secondary: c.secondary,
              onSecondary: NanoPaletteBrightness.foreground(c.secondary),
              secondaryContainer: c.secondaryContainer,
              onSecondaryContainer: c.onSurface,
              surface: c.surface,
              surfaceContainerLowest: c.backgroundDeep,
              surfaceContainer: c.surfaceVariant,
              surfaceContainerLow: c.backgroundPrimary,
              surfaceContainerHigh: c.backgroundElevated,
              surfaceContainerHighest: c.backgroundPearl,
              surfaceDim: c.backgroundSecondary,
              surfaceBright: c.surfaceVariant,
              onSurface: c.onSurface,
              onSurfaceVariant: c.onSurfaceVariant,
              outline: c.outline,
              outlineVariant: c.outlineVariant,
              error: c.error,
              tertiary: c.tertiary,
              onTertiary: NanoPaletteBrightness.foreground(c.tertiary),
            )
          : ColorScheme.light(
              primary: c.accent,
              onPrimary: c.onAccent,
              primaryContainer: c.primaryContainer,
              onPrimaryContainer: c.onPrimaryContainer,
              secondary: c.secondary,
              onSecondary: NanoPaletteBrightness.foreground(c.secondary),
              secondaryContainer: c.secondaryContainer,
              onSecondaryContainer: c.onSurface,
              surface: c.surface,
              surfaceContainer: c.backgroundElevated,
              surfaceContainerLow: c.backgroundPrimary,
              surfaceContainerHigh: c.surfaceVariant,
              surfaceContainerHighest: c.surfaceVariant,
              onSurface: c.onSurface,
              onSurfaceVariant: c.onSurfaceVariant,
              outline: c.outline,
              outlineVariant: c.outlineVariant,
              tertiary: c.tertiary,
              error: c.error,
            ),
      // Negro también en pantallas sin fondo decorativo. Claro y Gris espacial
      // conservan sus fondos existentes; los paneles usan GlassSurface aparte.
      scaffoldBackgroundColor: c is NanoDarkColors
          ? c.background
          : Colors.transparent,
      textTheme: _nanoTextTheme.copyWith(
        bodyLarge: _nanoTextTheme.bodyLarge?.copyWith(
          color: c.onSurface,
          fontWeight: FontWeight.w500,
        ),
        bodyMedium: _nanoTextTheme.bodyMedium?.copyWith(
          color: c.onSurface,
          fontWeight: FontWeight.w500,
        ),
        bodySmall: _nanoTextTheme.bodySmall?.copyWith(
          color: c.onSurfaceVariant,
          fontWeight: FontWeight.w500,
        ),
        titleLarge: _nanoTextTheme.titleLarge?.copyWith(
          color: c.onSurface,
          fontWeight: FontWeight.bold,
        ),
        titleMedium: _nanoTextTheme.titleMedium?.copyWith(
          color: c.onSurface,
          fontWeight: FontWeight.w600,
        ),
        headlineLarge: _nanoTextTheme.headlineLarge?.copyWith(
          color: c.onSurface,
          fontWeight: FontWeight.bold,
        ),
        headlineMedium: _nanoTextTheme.headlineMedium?.copyWith(
          color: c.onSurface,
          fontWeight: FontWeight.w600,
        ),
      ),
      iconTheme: IconThemeData(color: c.onSurface, size: 24),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: NanoPredictiveBackPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      extensions: [
        NanoThemeExtension(
          colors: c,
          glassEnabled: glassEnabled,
          glassOpacity: glassOpacity,
          glassClarity: glassClarity,
          glassBlur: glassBlur,
        ),
      ],
    );
    return _nanoThemeControls(_nanoThemeSurfaces(base, c, isDark), c, isDark);
  }

  /// Construye un tema dinámico con los parámetros ópticos de GlassSurface
  static ThemeData buildTheme(
    NanoColors c, {
    bool glassEnabled = true,
    double glassOpacity = 0.70,
    double glassClarity = 0.85,
    double glassBlur = 18.0,
  }) => _base(
    c,
    glassEnabled: glassEnabled,
    glassOpacity: glassOpacity,
    glassClarity: glassClarity,
    glassBlur: glassBlur,
  );

  /// Tema claro: paleta blanco y verde esmeralda / frost, superficies limpias de alto contraste.
  static final light = _base(const NanoLightColors());

  /// Tema clásico / azul: paleta blanco y azul profesional de alto contraste.
  static final classic = _base(const NanoClassicLightColors());

  /// Tema opaco / grisáceo: titanio pizarra mate, grafito y acentos metálicos (Space Gray).
  static final spaceGray = _base(const NanoSpaceGrayColors());

  /// Tema oscuro: negro neutro, superficies carbón y tipografía clara.
  static final dark = _base(const NanoDarkColors());

  static final systemLight = _base(const NanoSystemLightColors());

  static final systemDark = _base(const NanoSystemDarkColors());
}
