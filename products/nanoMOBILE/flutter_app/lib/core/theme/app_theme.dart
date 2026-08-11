import 'package:flutter/material.dart';
import 'design_tokens.dart';

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
    textTheme: _textTheme,
    cardTheme: CardThemeData(
      elevation: 2,
      shadowColor: c.primary.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: NanoShapes.medium,
        side: BorderSide(color: c.outlineVariant.withValues(alpha: 0.5), width: 1),
      ),
      margin: EdgeInsets.zero,
    ),
    appBarTheme: AppBarTheme(
      centerTitle: false,
      elevation: 0,
      backgroundColor: c.surface,
      titleTextStyle: _textTheme.titleMedium?.copyWith(color: c.onSurface),
      iconTheme: IconThemeData(color: c.onSurface),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: c.surface,
      indicatorColor: c.primaryContainer,
      elevation: 8,
      shadowColor: c.primary.withValues(alpha: 0.1),
      surfaceTintColor: c.primary.withValues(alpha: 0.05),
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
    ),
    dividerTheme: DividerThemeData(color: c.outlineVariant, thickness: 1, space: 0),
    // Transición de página consistente y ágil para cualquier push/route,
    // además de la transición custom por-pestaña definida en AppRouter.
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
    }),
    extensions: [NanoThemeExtension(colors: c)],
  );

  static final light = _base(NanoLightColors());
  static final dark = _base(NanoDarkColors());
}


