import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'design_tokens.dart';

class AppTheme {
  static final _textTheme = GoogleFonts.interTextTheme().copyWith(
    displayLarge: GoogleFonts.inter(fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: -0.5),
    headlineLarge: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.bold),
    headlineMedium: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w600),
    titleLarge: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold),
    titleMedium: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
    bodyLarge: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.normal),
    bodyMedium: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.normal),
    bodySmall: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.normal),
    labelLarge: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500),
    labelMedium: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500),
    labelSmall: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500),
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

/// ── Terminal-specific theme extension ──
class TerminalTheme extends ThemeExtension<TerminalTheme> {
  final Color background;
  final Color text;
  final Color accent;
  final Color dim;
  const TerminalTheme({required this.background, required this.text, required this.accent, required this.dim});

  @override
  ThemeExtension<TerminalTheme> copyWith({Color? background, Color? text, Color? accent, Color? dim}) =>
      TerminalTheme(background: background ?? this.background, text: text ?? this.text, accent: accent ?? this.accent, dim: dim ?? this.dim);

  @override
  ThemeExtension<TerminalTheme> lerp(ThemeExtension<TerminalTheme>? other, double t) => this;
}
