import 'package:flutter/material.dart';
import 'package:nanoai/core/theme/design_tokens.dart';
import 'package:nanoai/core/widgets/glass_surface.dart';
import 'package:nanoai/features/home/buho_wallpaper.dart';

part 'automation_visual_palette.part.dart';
part 'automation_visual_widgets.part.dart';

/// Lenguaje visual local de Automatización.
///
/// Diseño sobrio de inspiración iOS con colores calibrados en Claro y Oscuro.
enum AutomationVisualMode { system, lightGlass, dark }

abstract final class AutomationVisual {
  /// Acento del módulo: Azul iOS profesional para modo claro.
  static const lightAccent = Color(0xFF1D6FE8);

  static AutomationVisualMode modeFromSetting(String themeMode) =>
      switch (themeMode) {
        'Claro' => AutomationVisualMode.lightGlass,
        'Clásico' => AutomationVisualMode.lightGlass,
        'Oscuro' => AutomationVisualMode.dark,
        'Grisáceo' => AutomationVisualMode.dark,
        'Opaco' => AutomationVisualMode.dark,
        _ => AutomationVisualMode.system,
      };

  /// Paleta semántica del módulo derivada del tema real de la aplicación.
  static AutomationVisualPalette of(BuildContext context) {
    final scoped = Theme.of(context).extension<AutomationVisualTheme>();
    if (scoped != null) return scoped.palette;
    return _paletteFor(context, AutomationVisualMode.system);
  }

  static AutomationVisualPalette _paletteFor(
    BuildContext context,
    AutomationVisualMode mode,
  ) {
    final inherited = NanoThemeExtension.maybeOf(context);
    final colors =
        inherited?.colors ??
        switch (mode) {
          AutomationVisualMode.lightGlass => const NanoClassicLightColors(),
          AutomationVisualMode.dark => const NanoDarkColors(),
          AutomationVisualMode.system =>
            Theme.of(context).brightness == Brightness.dark
                ? const NanoDarkColors()
                : const NanoClassicLightColors(),
        };
    final isDark = NanoPaletteBrightness.isDark(colors);
    final themeExt = NanoThemeExtension.maybeOf(context);
    final glassOpacity = themeExt?.glassOpacity ?? 0.70;
    final glassClarity = themeExt?.glassClarity ?? 0.85;
    final glassEnabled = themeExt?.glassEnabled ?? true;

    final darkCardAlphaStart = !glassEnabled
        ? 1.0
        : ((0.18 + 0.65 * glassOpacity) * (1.15 - glassClarity * 0.40)).clamp(
            0.08,
            0.98,
          );
    final darkCardAlphaEnd = !glassEnabled
        ? 1.0
        : ((0.22 + 0.68 * glassOpacity) * (1.15 - glassClarity * 0.40)).clamp(
            0.10,
            0.98,
          );

    final lightCardAlphaStart = !glassEnabled
        ? 1.0
        : ((0.30 + 0.65 * glassOpacity) * (1.10 - glassClarity * 0.35)).clamp(
            0.12,
            0.98,
          );
    final lightCardAlphaEnd = !glassEnabled
        ? 1.0
        : ((0.25 + 0.65 * glassOpacity) * (1.10 - glassClarity * 0.35)).clamp(
            0.10,
            0.98,
          );

    final blackMode = NanoPaletteBrightness.isBlack(colors);
    final accentColor = blackMode ? const Color(0xFFE5E5EA) : colors.accent;

    return AutomationVisualPalette(
      resolvedColors: colors,
      isDark: isDark,
      accent: accentColor,
      onAccent: blackMode ? const Color(0xFF171719) : colors.onAccent,
      accentSoft: isDark
          ? accentColor.withValues(alpha: 0.16)
          : colors.primaryContainer,
      // Claro: fondo #F5F5F7, superficie #FFFFFF, texto #1D1D1F, secundario #595960.
      // Oscuro: fondo #111113, superficie #1C1C1E, texto #F5F5F7, secundario #B5B5BC.
      canvas: isDark ? const Color(0xFF111113) : const Color(0xFFF5F5F7),
      surface: isDark ? const Color(0xFF1C1C1E) : Colors.white,
      inputFill: isDark
          ? const Color(0xFF1C1C1E).withValues(alpha: 0.75)
          : const Color(0xFFF5F5F7),
      text: isDark ? const Color(0xFFF5F5F7) : const Color(0xFF1D1D1F),
      textMuted: isDark ? const Color(0xFFB5B5BC) : const Color(0xFF595960),
      line: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
      outline: isDark ? const Color(0xFF3A3A3C) : const Color(0xFFD1D1D6),
      cardStart: isDark
          ? const Color(0xFF1C1C1E).withValues(alpha: darkCardAlphaStart)
          : Colors.white.withValues(alpha: lightCardAlphaStart),
      cardEnd: isDark
          ? const Color(0xFF141416).withValues(alpha: darkCardAlphaEnd)
          : const Color(0xFFF5F5F7).withValues(alpha: lightCardAlphaEnd),
      cardBorder: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
      shadow: isDark ? const Color(0x35000000) : const Color(0x0A000000),
      shadowSoft: isDark ? const Color(0x20000000) : const Color(0x05000000),
      success: colors.success,
    );
  }

  static ThemeData theme(
    BuildContext context, {
    AutomationVisualMode mode = AutomationVisualMode.system,
  }) => _buildAutomationTheme(context, mode: mode);
}
