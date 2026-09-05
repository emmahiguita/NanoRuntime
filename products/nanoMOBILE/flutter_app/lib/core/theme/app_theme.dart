import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'design_tokens.dart';
import 'nano_transitions.dart';

class AppTheme {
  /// Inter desde ASSETS locales (offline-first). No usa GoogleFonts: con
  /// allowRuntimeFetching=false, cualquier fuente no cacheada lanzaba
  /// excepción y CRASHEABA el arranque. 'Inter' se registra en pubspec fonts.
  static const _textTheme = TextTheme(
    displayLarge: TextStyle(
      fontFamily: 'Inter',
      fontSize: 32,
      fontWeight: FontWeight.bold,
      letterSpacing: -0.5,
    ),
    headlineLarge: TextStyle(
      fontFamily: 'Inter',
      fontSize: 28,
      fontWeight: FontWeight.bold,
    ),
    headlineMedium: TextStyle(
      fontFamily: 'Inter',
      fontSize: 24,
      fontWeight: FontWeight.w600,
    ),
    titleLarge: TextStyle(
      fontFamily: 'Inter',
      fontSize: 20,
      fontWeight: FontWeight.bold,
    ),
    titleMedium: TextStyle(
      fontFamily: 'Inter',
      fontSize: 16,
      fontWeight: FontWeight.w600,
    ),
    bodyLarge: TextStyle(
      fontFamily: 'Inter',
      fontSize: 16,
      fontWeight: FontWeight.normal,
    ),
    bodyMedium: TextStyle(
      fontFamily: 'Inter',
      fontSize: 14,
      fontWeight: FontWeight.normal,
    ),
    bodySmall: TextStyle(
      fontFamily: 'Inter',
      fontSize: 12,
      fontWeight: FontWeight.normal,
    ),
    labelLarge: TextStyle(
      fontFamily: 'Inter',
      fontSize: 14,
      fontWeight: FontWeight.w500,
    ),
    labelMedium: TextStyle(
      fontFamily: 'Inter',
      fontSize: 12,
      fontWeight: FontWeight.w500,
    ),
    labelSmall: TextStyle(
      fontFamily: 'Inter',
      fontSize: 11,
      fontWeight: FontWeight.w500,
    ),
  );

  static ThemeData _base(NanoColors c) {
    final isDark = c is NanoDarkColors;

    return ThemeData(
      useMaterial3: true,
      brightness: isDark ? Brightness.dark : Brightness.light,
      colorScheme: isDark
          ? ColorScheme.dark(
              primary: c.primary,
              onPrimary: c.onAccent,
              primaryContainer: c.primaryContainer,
              onPrimaryContainer: c.onPrimaryContainer,
              secondary: c.secondary,
              secondaryContainer: c.secondaryContainer,
              surface: c.surface,
              surfaceContainer: c.surfaceVariant,
              onSurface: c.onSurface,
              onSurfaceVariant: c.onSurfaceVariant,
              outline: c.outline,
              outlineVariant: c.outlineVariant,
              error: c.error,
            )
          : ColorScheme.light(
              primary: c.accent,
              onPrimary: c.onAccent,
              primaryContainer: c.primaryContainer,
              onPrimaryContainer: c.onPrimaryContainer,
              secondary: c.secondary,
              secondaryContainer: c.secondaryContainer,
              surface: c.surface,
              surfaceContainer: c.surfaceVariant,
              surfaceContainerLow: c.backgroundPrimary,
              onSurface: c.onSurface,
              onSurfaceVariant: c.onSurfaceVariant,
              outline: c.outline,
              outlineVariant: c.outlineVariant,
              tertiary: c.tertiary,
              error: c.error,
            ),
      scaffoldBackgroundColor: c.background,
      textTheme: _textTheme.copyWith(
        bodyLarge: _textTheme.bodyLarge?.copyWith(
          color: c.onSurface,
          fontWeight: FontWeight.w500,
        ),
        bodyMedium: _textTheme.bodyMedium?.copyWith(
          color: c.onSurface,
          fontWeight: FontWeight.w500,
        ),
        bodySmall: _textTheme.bodySmall?.copyWith(
          color: c.onSurfaceVariant,
          fontWeight: FontWeight.w500,
        ),
        titleLarge: _textTheme.titleLarge?.copyWith(
          color: c.onSurface,
          fontWeight: FontWeight.bold,
        ),
        titleMedium: _textTheme.titleMedium?.copyWith(
          color: c.onSurface,
          fontWeight: FontWeight.w600,
        ),
        headlineLarge: _textTheme.headlineLarge?.copyWith(
          color: c.onSurface,
          fontWeight: FontWeight.bold,
        ),
        headlineMedium: _textTheme.headlineMedium?.copyWith(
          color: c.onSurface,
          fontWeight: FontWeight.w600,
        ),
      ),
      iconTheme: IconThemeData(color: c.onSurface, size: 24),
      cardTheme: CardThemeData(
        elevation: 0,
        color: isDark ? c.surface : c.glassSurface,
        surfaceTintColor: c.primary,
        shape: RoundedRectangleBorder(
          borderRadius: NanoShapes.large,
          side: BorderSide(
            color: isDark ? Colors.transparent : c.glassBorder,
            width: 1,
          ),
        ),
        margin: EdgeInsets.zero,
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 3,
        backgroundColor: isDark ? c.background : c.glassSurface,
        surfaceTintColor: c.primary,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
          systemNavigationBarColor: isDark ? c.background : c.backgroundPrimary,
          systemNavigationBarIconBrightness: isDark
              ? Brightness.light
              : Brightness.dark,
        ),
        titleTextStyle: _textTheme.titleMedium?.copyWith(
          color: c.onSurface,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(color: c.onSurface),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: c is NanoDarkColors
            ? c.surfaceVariant.withValues(alpha: 0.5)
            : c.glassSurface,
        indicatorColor: c.primaryContainer,
        elevation: 0,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: c.primary);
          }
          return IconThemeData(color: c.onSurfaceVariant);
        }),
      ),
      dividerTheme: DividerThemeData(
        color: c.outlineVariant.withValues(alpha: 0.5),
        thickness: 1,
        space: 0,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: c.onSurfaceVariant,
        textColor: c.onSurface,
        tileColor: Colors.transparent,
        selectedTileColor: c.primaryContainer.withValues(alpha: 0.3),
        selectedColor: c.primary,
        shape: const RoundedRectangleBorder(borderRadius: NanoShapes.medium),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: c.primary,
          foregroundColor: c.onAccent,
          elevation: 0, // M3 fully expressive buttons are flat by default
          shape: const StadiumBorder(), // M3 standard pill shape
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: NanoTextColors.forText(c.primary, c),
          side: BorderSide(color: c.outlineVariant, width: 1.5),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
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
        filled: true,
        fillColor: c is NanoDarkColors ? c.surfaceVariant : c.glassSurface,
        border: OutlineInputBorder(
          borderRadius: NanoShapes.extraLarge,
          borderSide: BorderSide(
            color: c is NanoDarkColors ? Colors.transparent : c.glassBorder,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: NanoShapes.extraLarge,
          borderSide: BorderSide(
            color: c is NanoDarkColors ? Colors.transparent : c.glassBorder,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: NanoShapes.extraLarge,
          borderSide: BorderSide(color: c.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 16,
        ),
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
      chipTheme: ChipThemeData(
        backgroundColor: c is NanoDarkColors
            ? c.surfaceVariant
            : c.glassSurface,
        selectedColor: c.primaryContainer,
        labelStyle: TextStyle(color: c.onSurface, fontWeight: FontWeight.w500),
        side: BorderSide(
          color: c is NanoDarkColors ? Colors.transparent : c.glassBorder,
        ),
        shape: const StadiumBorder(),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: c is NanoDarkColors ? c.surface : c.glassSurface,
        contentTextStyle: TextStyle(
          color: c.onSurface,
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: NanoShapes.medium,
          side: BorderSide(
            color: c is NanoDarkColors ? Colors.transparent : c.glassBorder,
          ),
        ),
        behavior: SnackBarBehavior.floating,
        elevation: 2,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c is NanoDarkColors ? c.surface : c.glassSurface,
        surfaceTintColor: c.primary, // Tonal elevation
        shape: RoundedRectangleBorder(
          borderRadius: NanoShapes.large,
          side: BorderSide(
            color: c is NanoDarkColors ? Colors.transparent : c.glassBorder,
          ),
        ),
        elevation: 4,
        titleTextStyle: TextStyle(
          color: c.onSurface,
          fontWeight: FontWeight.bold,
          fontSize: 24, // Expressive typography
        ),
        contentTextStyle: TextStyle(color: c.onSurfaceVariant, fontSize: 16),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c is NanoDarkColors ? c.surface : c.glassSurface,
        surfaceTintColor: c.primary,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(32),
          ), // Very organic top corners
          side: BorderSide(
            color: c is NanoDarkColors ? Colors.transparent : c.glassBorder,
          ),
        ),
        elevation: 2,
      ),
      // Transición de página unificada del sistema Nano (glass morph + gesto
      // predictivo de back en Android 14+). Antes dependía del tema (dark usaba
      // FadeForwards M3, light un fade+slide propio): la MISMA navegación
      // animaba distinto según modo claro/oscuro. Ahora es independiente del
      // tema. Las rutas de go_router usan CustomTransitionPage (AppRouter) —
      // este theme aplica al resto (rutas sueltas, preview de predictive back).
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: NanoPredictiveBackPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      extensions: [NanoThemeExtension(colors: c)],
    );
  }

  /// UI-REV-09: "Claro" ya no instala una paleta clara — instala la identidad
  /// oscura de Dev (borrador del usuario): fondo profundo, aurora azul de la
  /// barra de navegación (NAV-BAR-FIX-05), vidrio, textos claros. "Oscuro"
  /// conserva la gama menta/cyan y "Sistema" sigue el brillo del dispositivo.
  static final classic = _base(NanoClassicDarkColors());
  static final dark = _base(NanoDarkColors());
  static final light = systemLight;
  static final systemLight = _base(NanoSystemLightColors());
  static final systemDark = _base(NanoSystemDarkColors());
}
