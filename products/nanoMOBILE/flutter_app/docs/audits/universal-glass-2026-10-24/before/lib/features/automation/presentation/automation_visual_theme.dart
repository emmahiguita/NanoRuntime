import 'package:flutter/material.dart';
import 'package:nanoai/core/theme/design_tokens.dart';
import 'package:nanoai/core/widgets/glass_surface.dart';
import 'package:nanoai/features/home/buho_wallpaper.dart';

part 'automation_visual_palette.part.dart';
part 'automation_visual_widgets.part.dart';

/// Lenguaje visual local de Automatización.
///
/// Está deliberadamente acotado a este módulo: no cambia el tema elegido por
/// el usuario ni la apariencia de Chat, Terminal, Modelos o Ajustes.
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
  ///
  /// Automatización conserva su identidad de acento, pero no mantiene una
  /// segunda fuente de verdad para claro/oscuro. Esto evita que una ruta
  /// fuerce el modo claro cuando el usuario eligió Oscuro o Sistema.
  static AutomationVisualPalette of(BuildContext context) {
    final scoped = Theme.of(context).extension<AutomationVisualTheme>();
    if (scoped != null) return scoped.palette;
    return _paletteFor(context, AutomationVisualMode.system);
  }

  static AutomationVisualPalette _paletteFor(
    BuildContext context,
    AutomationVisualMode mode,
  ) {
    final inheritedColors = NanoThemeExtension.of(context).colors;
    final isDark = switch (mode) {
      AutomationVisualMode.lightGlass => false,
      AutomationVisualMode.dark => true,
      AutomationVisualMode.system =>
          inheritedColors is! NanoClassicLightColors &&
          inheritedColors is! NanoLightColors,
    };
    final colors = isDark
        ? (inheritedColors is! NanoClassicLightColors &&
                inheritedColors is! NanoLightColors
            ? inheritedColors
            : const NanoDarkColors())
        : (inheritedColors is NanoClassicLightColors ||
                inheritedColors is NanoLightColors
            ? inheritedColors
            : const NanoClassicLightColors());
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

    final accentColor = colors.accent;

    return AutomationVisualPalette(
      resolvedColors: colors,
      isDark: isDark,
      accent: accentColor,
      onAccent: Colors.white,
      accentSoft: isDark
          ? colors.primary.withValues(alpha: 0.20)
          : colors.primaryContainer,
      canvas: colors.backgroundPrimary,
      surface: isDark
          ? colors.glassPrimary.withValues(alpha: 0.72 * glassOpacity)
          : colors.glassSurface,
      inputFill: isDark
          ? colors.backgroundDeep.withValues(alpha: 0.62)
          : const Color(0xFFF1F5F9),
      text: colors.textPrimary,
      textMuted: colors.textSecondary,
      line: isDark ? colors.borderSecondaryColor : const Color(0xFFE2E8F0),
      outline: isDark ? colors.outline : const Color(0xFFCBD5E1),
      // Vidrio líquido iOS con alta transparencia y contraste cinematográfico
      cardStart: isDark
          ? const Color(0xFF0E182D).withValues(alpha: darkCardAlphaStart)
          : Colors.white.withValues(alpha: lightCardAlphaStart),
      cardEnd: isDark
          ? const Color(0xFF080E1D).withValues(alpha: darkCardAlphaEnd)
          : const Color(0xFFF8FAFC).withValues(alpha: lightCardAlphaEnd),
      cardBorder: isDark
          ? Colors.white.withValues(
              alpha: (0.05 + 0.20 * glassClarity).clamp(0.04, 0.35),
            )
          : const Color(0xFFE2E8F0),
      shadow: isDark ? const Color(0x35000000) : const Color(0x0C0F172A),
      shadowSoft: isDark ? const Color(0x200D1F4A) : const Color(0x060F172A),
      success: isDark ? const Color(0xFF38BDF8) : const Color(0xFF1D6FE8),
    );
  }

  /// Adapta los componentes Material del módulo sin sustituir el ThemeData
  /// global. Se preservan extensiones, tipografía, plataforma y transiciones
  /// del diseño clásico de Nano.
  static ThemeData theme(
    BuildContext context, {
    AutomationVisualMode mode = AutomationVisualMode.system,
  }) => _buildAutomationTheme(context, mode: mode);
}
