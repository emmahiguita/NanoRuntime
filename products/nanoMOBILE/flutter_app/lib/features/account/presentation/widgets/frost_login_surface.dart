import 'package:flutter/material.dart';
import '../../../../core/theme/design_tokens.dart';

/// Superficie de acceso estilo iOS Glass sobria y profesional.
/// Respeta el tema visual de la aplicación sin sobreescribir colores con tonos estridentes.
class FrostLoginSurface extends StatelessWidget {
  const FrostLoginSurface({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final themeExt = NanoThemeExtension.maybeOf(context);
    final colors = themeExt?.colors ?? const NanoDarkColors();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final colorScheme = ColorScheme.fromSeed(
      seedColor: colors.primary,
      brightness: isDark ? Brightness.dark : Brightness.light,
    ).copyWith(
      surface: colors.background,
      onSurface: colors.onSurface,
      onSurfaceVariant: colors.onSurfaceVariant,
      primary: colors.primary,
      onPrimary: Colors.white,
      surfaceContainerLow: isDark
          ? colors.surface.withValues(alpha: 0.65)
          : colors.backgroundElevated.withValues(alpha: 0.85),
      outlineVariant: colors.outlineVariant.withValues(alpha: isDark ? 0.35 : 0.45),
    );

    return Theme(
      data: ThemeData(
        useMaterial3: true,
        colorScheme: colorScheme,
        fontFamily: 'Inter',
        scaffoldBackgroundColor: Colors.transparent,
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: colors.primary,
            textStyle: const TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w600,
              fontSize: 13.5,
              decoration: TextDecoration.none,
            ),
          ),
        ),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.background,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: isDark
                  ? [
                      colors.background,
                      colors.surface.withValues(alpha: 0.95),
                      colors.background,
                    ]
                  : [
                      colors.background,
                      colors.backgroundElevated,
                      colors.background,
                    ],
            ),
          ),
          child: DefaultTextStyle(
            style: TextStyle(
              fontFamily: 'Inter',
              color: colors.onSurface,
              decoration: TextDecoration.none,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
