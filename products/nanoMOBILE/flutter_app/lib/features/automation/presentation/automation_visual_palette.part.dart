part of 'automation_visual_theme.dart';

ThemeData _buildAutomationTheme(
  BuildContext context, {
  AutomationVisualMode mode = AutomationVisualMode.system,
}) {
  final base = Theme.of(context);
  final visual = AutomationVisual._paletteFor(context, mode);
  final scheme = base.colorScheme.copyWith(
    brightness: visual.isDark ? Brightness.dark : Brightness.light,
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
        (extension) =>
            extension is! AutomationVisualTheme &&
            // UI-REV-02: la extensión global se sustituye por la familia
            // resuelta — fuera la mezcla claro/oscuro de las secciones
            // que leen NanoThemeExtension.of(context).
            extension is! NanoThemeExtension,
      ),
      // Conserva los ajustes globales de cristal; no crea otra configuración.
      NanoThemeExtension.of(context).copyWith(colors: visual.resolvedColors),
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
      hintStyle: TextStyle(color: visual.textMuted),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
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
        (states) =>
            states.contains(WidgetState.selected) ? visual.accent : visual.line,
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

@immutable
class AutomationVisualPalette {
  const AutomationVisualPalette({
    required this.resolvedColors,
    required this.isDark,
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

  final NanoColors resolvedColors;
  final bool isDark;
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
        resolvedColors:
            (NanoThemeExtension(
                      colors: resolvedColors,
                    ).lerp(NanoThemeExtension(colors: other.resolvedColors), t)
                    as NanoThemeExtension)
                .colors,
        isDark: t < 0.5 ? isDark : other.isDark,
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
