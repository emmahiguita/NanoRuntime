import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:nanoai/core/theme/design_tokens.dart';

/// Lenguaje visual local de Automatización.
///
/// Está deliberadamente acotado a este módulo: no cambia el tema elegido por
/// el usuario ni la apariencia de Chat, Terminal, Modelos o Ajustes.
abstract final class AutomationVisual {
  static const accent = Color(0xFFFF7A00);
  static const accentSoft = Color(0xFFFFF2E7);
  static const canvas = Color(0xFFF8F9FB);
  static const surface = Color(0xFFFFFFFF);
  static const text = Color(0xFF1B1E25);
  static const textMuted = Color(0xFF707681);
  static const line = Color(0xFFE8EAEE);

  static ThemeData theme() {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: accent,
          brightness: Brightness.light,
          surface: surface,
        ).copyWith(
          primary: accent,
          onPrimary: Colors.white,
          surface: surface,
          onSurface: text,
          outline: const Color(0xFFC9CDD3),
          outlineVariant: line,
        );
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: 'Inter',
      colorScheme: scheme,
      scaffoldBackgroundColor: canvas,
      extensions: [NanoThemeExtension(colors: NanoLightColors())],
    );
    return base.copyWith(
      textTheme: base.textTheme.apply(
        bodyColor: text,
        displayColor: text,
        fontFamily: 'Inter',
      ),
      dividerColor: line,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFFBFBFC),
        hintStyle: const TextStyle(color: Color(0xFF9AA0AA)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 15,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: const BorderSide(color: line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: const BorderSide(color: line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: const BorderSide(color: accent, width: 1.6),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
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
              ? accent
              : const Color(0xFFD9DCE1),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            color: states.contains(WidgetState.selected) ? accent : textMuted,
            fontSize: 9.5,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
            letterSpacing: -0.25,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected) ? accent : textMuted,
            size: 23,
          ),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
      ),
    );
  }
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
    final borderRadius = BorderRadius.circular(radius);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: const [
          BoxShadow(
            color: Color(0x120D1726),
            blurRadius: 28,
            offset: Offset(0, 10),
            spreadRadius: -8,
          ),
          BoxShadow(
            color: Color(0x0A0D1726),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 13, sigmaY: 13),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xF7FFFFFF), Color(0xDFFFFFFF)],
              ),
              borderRadius: borderRadius,
              border: Border.all(color: const Color(0xE6FFFFFF), width: 1.1),
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
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 10),
    child: Text(
      label.toUpperCase(),
      style: const TextStyle(
        color: AutomationVisual.textMuted,
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.7,
      ),
    ),
  );
}
