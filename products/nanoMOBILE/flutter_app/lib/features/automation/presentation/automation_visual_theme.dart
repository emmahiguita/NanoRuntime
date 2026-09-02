import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:nanoai/core/theme/design_tokens.dart';

/// Lenguaje visual local de Automatización.
///
/// Está deliberadamente acotado a este módulo: no cambia el tema elegido por
/// el usuario ni la apariencia de Chat, Terminal, Modelos o Ajustes.
enum AutomationVisualMode { system, lightGlass, dark }

abstract final class AutomationVisual {
  static const lightAccent = Color(0xFFFF7A00);

  static AutomationVisualMode modeFromSetting(String themeMode) =>
      switch (themeMode) {
        'Claro' => AutomationVisualMode.lightGlass,
        'Oscuro' => AutomationVisualMode.dark,
        _ => AutomationVisualMode.system,
      };

  /// Paleta semántica del módulo derivada del tema real de la aplicación.
  ///
  /// Automatización conserva su identidad naranja, pero no mantiene una
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
    final theme = Theme.of(context);
    final inheritedColors = NanoThemeExtension.of(context).colors;
    final isDark =
        mode == AutomationVisualMode.dark ||
        (mode == AutomationVisualMode.system &&
            theme.brightness == Brightness.dark);
    final isLightGlass = mode == AutomationVisualMode.lightGlass;
    final isGlass = mode != AutomationVisualMode.system;
    // "Sistema" conserva la identidad naranja de Nano Automation aunque el
    // brillo del dispositivo sea oscuro. Solo el modo Oscuro explícito adopta
    // el acento óptico menta del shell nocturno.
    final usesDarkAccent = mode == AutomationVisualMode.dark;
    final colors = isDark
        ? inheritedColors is NanoDarkColors
              ? inheritedColors
              : NanoDarkColors()
        : inheritedColors is NanoDarkColors
        ? NanoLightColors()
        : inheritedColors;
    return AutomationVisualPalette(
      isDark: isDark,
      isGlass: isGlass,
      isLightGlass: isLightGlass,
      accent: usesDarkAccent ? colors.accentMint : lightAccent,
      onAccent: usesDarkAccent ? colors.onAccent : Colors.white,
      accentSoft: usesDarkAccent
          ? colors.accentMint.withValues(alpha: 0.14)
          : isDark
          ? lightAccent.withValues(alpha: 0.17)
          : isLightGlass
          ? const Color(0xB8FFF2E7)
          : const Color(0xFFFFF2E7),
      canvas: isDark
          ? colors.backgroundPrimary
          : isLightGlass
          ? colors.backgroundPrimary
          : const Color(0xFFF8F9FB),
      surface: isDark
          ? colors.glassPrimary.withValues(alpha: 0.72)
          : isLightGlass
          ? colors.glassSurface
          : const Color(0xFFFFFFFF),
      inputFill: isDark
          ? colors.backgroundDeep.withValues(alpha: 0.62)
          : isLightGlass
          ? colors.glassSecondary.withValues(alpha: 0.56)
          : const Color(0xFFFBFBFC),
      text: colors.textPrimary,
      textMuted: colors.textSecondary,
      line: isDark
          ? colors.borderSecondaryColor
          : isLightGlass
          ? colors.borderSecondaryColor
          : const Color(0xFFE8EAEE),
      outline: isDark ? colors.outline : const Color(0xFFC9CDD3),
      cardStart: isDark
          ? colors.glass100.withValues(alpha: 0.84)
          : isLightGlass
          ? colors.glassPrimary.withValues(alpha: colors.glassOpaque)
          : const Color(0xF7FFFFFF),
      cardEnd: isDark
          ? colors.glassBlue.withValues(alpha: 0.62)
          : isLightGlass
          ? colors.glassSecondary.withValues(alpha: colors.glassMedium)
          : const Color(0xDFFFFFFF),
      cardBorder: isDark
          ? usesDarkAccent
                ? colors.borderAccentColor
                : lightAccent.withValues(alpha: 0.28)
          : isLightGlass
          ? colors.borderPrimaryColor
          : const Color(0xE6FFFFFF),
      shadow: isDark
          ? const Color(0x59000000)
          : isGlass
          ? const Color(0x160D1726)
          : const Color(0x120D1726),
      shadowSoft: isDark
          ? const Color(0x33000000)
          : isGlass
          ? const Color(0x0D0D1726)
          : const Color(0x0A0D1726),
      success: colors.success,
    );
  }

  /// Adapta los componentes Material del módulo sin sustituir el ThemeData
  /// global. Se preservan extensiones, tipografía, plataforma y transiciones
  /// del diseño clásico de Nano.
  static ThemeData theme(
    BuildContext context, {
    AutomationVisualMode mode = AutomationVisualMode.system,
  }) {
    final base = Theme.of(context);
    final visual = _paletteFor(context, mode);
    final scheme = base.colorScheme.copyWith(
      primary: visual.accent,
      onPrimary: visual.onAccent,
      surface: visual.surface,
      onSurface: visual.text,
      outline: visual.outline,
      outlineVariant: visual.line,
    );
    return base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: visual.canvas,
      extensions: [
        ...base.extensions.values.where(
          (extension) => extension is! AutomationVisualTheme,
        ),
        AutomationVisualTheme(palette: visual),
      ],
      textTheme: base.textTheme.apply(
        bodyColor: visual.text,
        displayColor: visual.text,
        fontFamily: 'Inter',
      ),
      dividerColor: visual.line,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: visual.inputFill,
        hintStyle: TextStyle(color: visual.textMuted.withValues(alpha: 0.72)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 15,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: BorderSide(color: visual.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: BorderSide(color: visual.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: BorderSide(color: visual.accent, width: 1.6),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: visual.accent,
          foregroundColor: visual.onAccent,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? Colors.white
              : const Color(0xFFF4F4F5),
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? visual.accent
              : visual.line,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            color: states.contains(WidgetState.selected)
                ? visual.accent
                : visual.textMuted,
            fontSize: 9.5,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
            letterSpacing: -0.25,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? visual.accent
                : visual.textMuted,
            size: 23,
          ),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: visual.surface,
        surfaceTintColor: Colors.transparent,
      ),
    );
  }
}

@immutable
class AutomationVisualPalette {
  const AutomationVisualPalette({
    required this.isDark,
    required this.isGlass,
    required this.isLightGlass,
    required this.accent,
    required this.onAccent,
    required this.accentSoft,
    required this.canvas,
    required this.surface,
    required this.inputFill,
    required this.text,
    required this.textMuted,
    required this.line,
    required this.outline,
    required this.cardStart,
    required this.cardEnd,
    required this.cardBorder,
    required this.shadow,
    required this.shadowSoft,
    required this.success,
  });

  final bool isDark;
  final bool isGlass;
  final bool isLightGlass;
  final Color accent;
  final Color onAccent;
  final Color accentSoft;
  final Color canvas;
  final Color surface;
  final Color inputFill;
  final Color text;
  final Color textMuted;
  final Color line;
  final Color outline;
  final Color cardStart;
  final Color cardEnd;
  final Color cardBorder;
  final Color shadow;
  final Color shadowSoft;
  final Color success;

  AutomationVisualPalette lerp(AutomationVisualPalette other, double t) =>
      AutomationVisualPalette(
        isDark: t < 0.5 ? isDark : other.isDark,
        isGlass: t < 0.5 ? isGlass : other.isGlass,
        isLightGlass: t < 0.5 ? isLightGlass : other.isLightGlass,
        accent: Color.lerp(accent, other.accent, t)!,
        onAccent: Color.lerp(onAccent, other.onAccent, t)!,
        accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
        canvas: Color.lerp(canvas, other.canvas, t)!,
        surface: Color.lerp(surface, other.surface, t)!,
        inputFill: Color.lerp(inputFill, other.inputFill, t)!,
        text: Color.lerp(text, other.text, t)!,
        textMuted: Color.lerp(textMuted, other.textMuted, t)!,
        line: Color.lerp(line, other.line, t)!,
        outline: Color.lerp(outline, other.outline, t)!,
        cardStart: Color.lerp(cardStart, other.cardStart, t)!,
        cardEnd: Color.lerp(cardEnd, other.cardEnd, t)!,
        cardBorder: Color.lerp(cardBorder, other.cardBorder, t)!,
        shadow: Color.lerp(shadow, other.shadow, t)!,
        shadowSoft: Color.lerp(shadowSoft, other.shadowSoft, t)!,
        success: Color.lerp(success, other.success, t)!,
      );
}

@immutable
class AutomationVisualTheme extends ThemeExtension<AutomationVisualTheme> {
  const AutomationVisualTheme({required this.palette});

  final AutomationVisualPalette palette;

  @override
  AutomationVisualTheme copyWith({AutomationVisualPalette? palette}) =>
      AutomationVisualTheme(palette: palette ?? this.palette);

  @override
  AutomationVisualTheme lerp(
    covariant ThemeExtension<AutomationVisualTheme>? other,
    double t,
  ) => other is AutomationVisualTheme
      ? AutomationVisualTheme(palette: palette.lerp(other.palette, t))
      : this;
}

class AutomationSurfaceCard extends StatelessWidget {
  const AutomationSurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.onTap,
    this.radius = 24,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final visual = AutomationVisual.of(context);
    final borderRadius = BorderRadius.circular(radius);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: [
          BoxShadow(
            color: visual.shadow,
            blurRadius: 28,
            offset: const Offset(0, 10),
            spreadRadius: -8,
          ),
          BoxShadow(
            color: visual.shadowSoft,
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 13, sigmaY: 13),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [visual.cardStart, visual.cardEnd],
              ),
              borderRadius: borderRadius,
              border: Border.all(color: visual.cardBorder, width: 1.1),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                borderRadius: borderRadius,
                child: Padding(padding: padding, child: child),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AutomationSectionLabel extends StatelessWidget {
  const AutomationSectionLabel(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    final visual = AutomationVisual.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: visual.textMuted,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.7,
        ),
      ),
    );
  }
}
