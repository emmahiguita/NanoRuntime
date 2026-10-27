part of 'app_theme.dart';

/// Controles Material que leen la misma paleta y brillo global.
ThemeData _nanoThemeControls(
  ThemeData base,
  NanoColors c,
  bool isDark,
) => base.copyWith(
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: isDark
          ? c.primary.withValues(alpha: 0.16)
          : c.primary.withValues(alpha: 0.12),
      foregroundColor: isDark ? c.onSurface : c.primary,
      elevation: 0,
      side: BorderSide(
        color: c.primary.withValues(alpha: isDark ? 0.38 : 0.28),
        width: 1.0,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      textStyle: const TextStyle(
        fontFamily: 'Inter',
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
    ),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      backgroundColor: isDark
          ? c.primary.withValues(alpha: 0.16)
          : c.primary.withValues(alpha: 0.12),
      foregroundColor: isDark ? c.onSurface : c.primary,
      elevation: 0,
      side: BorderSide(
        color: c.primary.withValues(alpha: isDark ? 0.38 : 0.28),
        width: 1.0,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      textStyle: const TextStyle(
        fontFamily: 'Inter',
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: c.onSurface.withValues(alpha: 0.85),
      side: BorderSide(
        color: c.outlineVariant.withValues(alpha: 0.45),
        width: 1.0,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      textStyle: const TextStyle(
        fontFamily: 'Inter',
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: NanoTextColors.forText(c.primary, c),
      textStyle: const TextStyle(fontWeight: FontWeight.w600),
      shape: const StadiumBorder(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    ),
  ),
  floatingActionButtonTheme: FloatingActionButtonThemeData(
    backgroundColor: c.primaryContainer,
    foregroundColor: c.onPrimaryContainer,
    elevation: 3,
    shape: const RoundedRectangleBorder(
      borderRadius: NanoShapes.extraLarge, // Large organic corner
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    // En modo claro usa superficie blanca elevada (#FFFFFF) con borde definido
    filled: true,
    fillColor: isDark ? c.surfaceVariant : c.backgroundElevated,
    border: OutlineInputBorder(
      borderRadius: NanoShapes.extraLarge,
      borderSide: BorderSide(color: isDark ? Colors.transparent : c.outline),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: NanoShapes.extraLarge,
      borderSide: BorderSide(color: isDark ? Colors.transparent : c.outline),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: NanoShapes.extraLarge,
      borderSide: BorderSide(color: c.primary, width: 2),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    labelStyle: TextStyle(color: c.onSurfaceVariant),
    hintStyle: TextStyle(color: c.onSurfaceVariant.withValues(alpha: 0.7)),
  ),
  switchTheme: SwitchThemeData(
    thumbColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) {
        return c.onPrimaryContainer;
      }
      return c.outline;
    }),
    trackColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) return c.primaryContainer;
      return c.surfaceVariant;
    }),
  ),
  sliderTheme: SliderThemeData(
    activeTrackColor: c.primary,
    inactiveTrackColor: c.surfaceVariant,
    thumbColor: c.primary,
    overlayColor: c.primary.withValues(alpha: 0.1),
  ),
);
