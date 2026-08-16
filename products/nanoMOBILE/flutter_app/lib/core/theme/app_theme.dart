import 'package:flutter/material.dart';
import 'design_tokens.dart';
import 'adaptive_theme.dart';

class AppTheme {
  /// Inter desde ASSETS locales (offline-first). No usa GoogleFonts: con
  /// allowRuntimeFetching=false, cualquier fuente no cacheada lanzaba
  /// excepción y CRASHEABA el arranque. 'Inter' se registra en pubspec fonts.
  static const _textTheme = TextTheme(
    displayLarge: TextStyle(fontFamily: 'Inter', fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: -0.5),
    headlineLarge: TextStyle(fontFamily: 'Inter', fontSize: 28, fontWeight: FontWeight.bold),
    headlineMedium: TextStyle(fontFamily: 'Inter', fontSize: 24, fontWeight: FontWeight.w600),
    titleLarge: TextStyle(fontFamily: 'Inter', fontSize: 20, fontWeight: FontWeight.bold),
    titleMedium: TextStyle(fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.w600),
    bodyLarge: TextStyle(fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.normal),
    bodyMedium: TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.normal),
    bodySmall: TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.normal),
    labelLarge: TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w500),
    labelMedium: TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w500),
    labelSmall: TextStyle(fontFamily: 'Inter', fontSize: 11, fontWeight: FontWeight.w500),
  );

  static ThemeData _base(NanoColors c) => ThemeData(
    useMaterial3: true,
    brightness: c is NanoDarkColors ? Brightness.dark : Brightness.light,
    colorSchemeSeed: c.primary,
    scaffoldBackgroundColor: c.background,
    textTheme: _textTheme.copyWith(
      // Mejorar contraste de textos en modo claro sobre glassmorphism
      bodyLarge: _textTheme.bodyLarge?.copyWith(
        color: c.onSurface,
        fontWeight: FontWeight.w500, // Más peso para mejor legibilidad
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
    iconTheme: IconThemeData(
      color: c.onSurface,
      size: 24,
    ),
    cardTheme: CardThemeData(
      elevation: 2,
      shadowColor: c is NanoDarkColors 
        ? const Color(0xFF000000).withValues(alpha: 0.3)
        : const Color(0xFF000000).withValues(alpha: 0.06),
      color: c is NanoDarkColors ? c.surface : c.glassSurface, // Glassmorphism en modo claro
      shape: RoundedRectangleBorder(
        borderRadius: NanoShapes.medium,
        side: BorderSide(
          color: c is NanoDarkColors 
            ? c.outlineVariant.withValues(alpha: 0.5)
            : c.glassBorder, // Borde cristal en modo claro
          width: 1
        ),
      ),
      margin: EdgeInsets.zero,
    ),
    appBarTheme: AppBarTheme(
      centerTitle: false,
      elevation: 0,
      backgroundColor: c is NanoDarkColors ? c.surface : c.glassSurface, // Glassmorphism en modo claro
      titleTextStyle: _textTheme.titleMedium?.copyWith(
        color: c.onSurface,
        fontWeight: FontWeight.w600,
      ),
      iconTheme: IconThemeData(color: c.onSurface),
      // Sombra sutil en modo claro para profundidad
      shadowColor: c is NanoDarkColors 
        ? Colors.transparent 
        : const Color(0xFF000000).withValues(alpha: 0.05),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: c is NanoDarkColors ? c.surface : c.glassSurface, // Glassmorphism en modo claro
      indicatorColor: c.primaryContainer,
      elevation: 8,
      shadowColor: c is NanoDarkColors 
        ? const Color(0xFF000000).withValues(alpha: 0.4)
        : const Color(0xFF000000).withValues(alpha: 0.10),
      surfaceTintColor: c.primary.withValues(alpha: 0.05),
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return IconThemeData(color: c.primary);
        }
        return IconThemeData(color: c.onSurfaceVariant);
      }),
    ),
    dividerTheme: DividerThemeData(
      color: c.outlineVariant, 
      thickness: 1, 
      space: 0,
    ),
    // Mejorar contraste en listas y tiles
    listTileTheme: ListTileThemeData(
      iconColor: c.onSurfaceVariant,
      textColor: c.onSurface,
      tileColor: c.surfaceVariant.withValues(alpha: c is NanoDarkColors ? 0.3 : 0.5),
      selectedTileColor: c.primaryContainer.withValues(alpha: 0.3),
      selectedColor: c.primary,
    ),
    // Mejorar contraste en botones elevated
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: c.primary,
        foregroundColor: c is NanoDarkColors ? const Color(0xFF000000) : const Color(0xFFFFFFFF),
        elevation: 2,
        shadowColor: c is NanoDarkColors 
          ? Colors.transparent 
          : const Color(0xFF000000).withValues(alpha: 0.15),
        shape: const RoundedRectangleBorder(
          borderRadius: NanoShapes.medium,
        ),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    // Mejorar contraste en botones outlined
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: c.primary,
        side: BorderSide(
          color: c.primary.withValues(alpha: c is NanoDarkColors ? 0.5 : 0.7),
          width: 1.5,
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: NanoShapes.medium,
        ),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    // Mejorar botones de texto
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: c.primary,
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    // Floating Action Button con sombra profesional
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: c.primary,
      foregroundColor: c is NanoDarkColors ? const Color(0xFF000000) : const Color(0xFFFFFFFF),
      elevation: 6,
      shape: const RoundedRectangleBorder(
        borderRadius: NanoShapes.extraLarge,
      ),
    ),
    // Input decoration para campos de texto
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c is NanoDarkColors
        ? c.surfaceVariant.withValues(alpha: 0.3)
        : c.surfaceVariant.withValues(alpha: 0.7), // Slate-50 casi opaco: el
        // glassSurface al 43% dejaba el campo confundido con el fondo blanco
      border: OutlineInputBorder(
        borderRadius: NanoShapes.medium,
        borderSide: BorderSide(color: c.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: NanoShapes.medium,
        borderSide: BorderSide(color: c.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: NanoShapes.medium,
        borderSide: BorderSide(color: c.primary, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      labelStyle: TextStyle(color: c.onSurfaceVariant),
      hintStyle: TextStyle(color: c.onSurfaceVariant.withValues(alpha: 0.7)),
    ),
    // Switch personalizado
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return c.primary;
        }
        return c.outline;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return c.primary.withValues(alpha: 0.5);
        }
        return c.outlineVariant;
      }),
    ),
    // Slider personalizado
    sliderTheme: SliderThemeData(
      activeTrackColor: c.primary,
      inactiveTrackColor: c.outlineVariant,
      thumbColor: c.primary,
      overlayColor: c.primary.withValues(alpha: 0.1),
    ),
    // Chip personalizado
    chipTheme: ChipThemeData(
      backgroundColor: c is NanoDarkColors ? c.surfaceVariant : c.glassSurface, // Glassmorphism en modo claro
      selectedColor: c.primaryContainer,
      labelStyle: TextStyle(
        color: c.onSurface,
        fontWeight: FontWeight.w500,
      ),
      side: BorderSide.none,
      shape: const RoundedRectangleBorder(
        borderRadius: NanoShapes.full,
      ),
    ),
    // SnackBar personalizado con Glassmorphism
    snackBarTheme: SnackBarThemeData(
      backgroundColor: c is NanoDarkColors ? c.surface : c.glassSurface, // Glassmorphism en modo claro
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
      elevation: 4,
    ),
    // Dialog personalizado con Glassmorphism
    dialogTheme: DialogThemeData(
      backgroundColor: c is NanoDarkColors ? c.surface : c.glassSurface, // Glassmorphism en modo claro
      shape: RoundedRectangleBorder(
        borderRadius: NanoShapes.large,
        side: BorderSide(
          color: c is NanoDarkColors ? Colors.transparent : c.glassBorder,
        ),
      ),
      elevation: 8,
      titleTextStyle: TextStyle(
        color: c.onSurface,
        fontWeight: FontWeight.bold,
      ),
      contentTextStyle: TextStyle(
        color: c.onSurface,
      ),
    ),
    // BottomSheet personalizado con Glassmorphism
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: c is NanoDarkColors ? c.surface : c.glassSurface, // Glassmorphism en modo claro
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        side: BorderSide(
          color: c is NanoDarkColors ? Colors.transparent : c.glassBorder,
        ),
      ),
      elevation: 8,
    ),
    // Transición de página consistente y ágil para cualquier push/route,
    // además de la transición custom por-pestaña definida en AppRouter.
    pageTransitionsTheme: PageTransitionsTheme(builders: {
      TargetPlatform.android: _AdaptivePageTransitionBuilder(),
      TargetPlatform.iOS: const CupertinoPageTransitionsBuilder(),
    }),
    extensions: [NanoThemeExtension(colors: c)],
  );

  /// Temas claro y oscuro. Estaban dentro de _AdaptivePageTransitionBuilder
  /// (llave mal cerrada en el refactor) — main.dart los llama AppTheme.light
  /// y AppTheme.dark, así que viven en AppTheme.
  static final light = _base(NanoLightColors());
  static final dark = _base(NanoDarkColors());
}

/// Custom page transition builder adaptativo para modo claro con glassmorphism
class _AdaptivePageTransitionBuilder extends PageTransitionsBuilder {
  @override
  Widget buildTransitions<T>(
    PageRoute<T>? route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final colors = Theme.of(context).extension<NanoThemeExtension>()?.colors;
    final isLight = colors is NanoLightColors;
    final isLandscape = AdaptiveTheme.isLandscape(context);

    if (!isLight) {
      return const FadeForwardsPageTransitionsBuilder().buildTransitions(
        route,
        context,
        animation,
        secondaryAnimation,
        child,
      );
    }

    // Adaptar animación según orientación
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: Offset(0, isLandscape ? 0.05 : 0.1),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: animation,
          curve: NanoCurves.easeOut,
        )),
        child: child,
      ),
    );
  }
}

