import 'package:flutter/material.dart';

/// ── Semantic Color Tokens (shared interface) ──
abstract class NanoColors {
  Color get primary;
  Color get primaryContainer;
  Color get onPrimaryContainer;
  Color get secondary;
  Color get secondaryContainer;
  Color get surface;
  Color get surfaceVariant;
  Color get background;
  Color get onSurface;
  Color get onSurfaceVariant;
  Color get outline;
  Color get outlineVariant;
  Color get success;
  Color get warning;
  Color get error;
  Color get info;
  Color get terminalBg;
  Color get terminalGreen;
}

class NanoDarkColors implements NanoColors {
  @override final primary = const Color(0xFF00E676);
  @override final primaryContainer = const Color(0xFF0A3D1F);
  @override final onPrimaryContainer = const Color(0xFFB9F6CA);
  @override final secondary = const Color(0xFF38BDF8);
  @override final secondaryContainer = const Color(0xFF0C2D48);
  @override final surface = const Color(0xFF0F172A);
  @override final surfaceVariant = const Color(0xFF1E293B);
  @override final background = const Color(0xFF07090E);
  @override final onSurface = const Color(0xFFF8FAFC);
  @override final onSurfaceVariant = const Color(0xFF94A3B8);
  @override final outline = const Color(0xFF475569);
  @override final outlineVariant = const Color(0xFF1E293B);
  @override final success = const Color(0xFF00E676);
  @override final warning = const Color(0xFFF59E0B);
  @override final error = const Color(0xFFEF4444);
  @override final info = const Color(0xFF38BDF8);
  @override final terminalBg = const Color(0xFF050810);
  @override final terminalGreen = const Color(0xFF00E676);
}

class NanoLightColors implements NanoColors {
  @override final primary = const Color(0xFF008F39);
  @override final primaryContainer = const Color(0xFFB9F6CA);
  @override final onPrimaryContainer = const Color(0xFF002106);
  @override final secondary = const Color(0xFF0284C7);
  @override final secondaryContainer = const Color(0xFFBAE6FD);
  @override final surface = const Color(0xFFFFFFFF);
  @override final surfaceVariant = const Color(0xFFF1F5F9);
  @override final background = const Color(0xFFF8FAFC);
  @override final onSurface = const Color(0xFF0F172A);
  @override final onSurfaceVariant = const Color(0xFF475569);
  @override final outline = const Color(0xFF94A3B8);
  @override final outlineVariant = const Color(0xFFCBD5E1);
  @override final success = const Color(0xFF16A34A);
  @override final warning = const Color(0xFFD97706);
  @override final error = const Color(0xFFDC2626);
  @override final info = const Color(0xFF0284C7);
  @override final terminalBg = const Color(0xFFF1F5F9);
  @override final terminalGreen = const Color(0xFF008F39);
}

/// ── Spacing Tokens (8dp grid) ──
class NanoSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
  static const xxxl = 48.0;
  static const statCardHeight = 100.0;
  static const minTouch = 44.0;
}

/// ── Animation Tokens ──
class NanoDurations {
  static const fast = Duration(milliseconds: 150);
  static const normal = Duration(milliseconds: 250);
  static const slow = Duration(milliseconds: 400);
  static const shimmer = Duration(milliseconds: 900);
}

/// ── Shape Tokens ──
class NanoShapes {
  static const small = BorderRadius.all(Radius.circular(6));
  static const medium = BorderRadius.all(Radius.circular(10));
  static const large = BorderRadius.all(Radius.circular(14));
  static const extraLarge = BorderRadius.all(Radius.circular(20));
  static const full = BorderRadius.all(Radius.circular(100));
  static const userBubble = BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16), bottomLeft: Radius.circular(16), bottomRight: Radius.circular(4));
  static const aiBubble = BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16), bottomLeft: Radius.circular(4), bottomRight: Radius.circular(16));
}

/// ── Shadow Tokens ──
class NanoShadows {
  static List<BoxShadow> card(NanoColors c) => [BoxShadow(color: c is NanoDarkColors ? c.primary.withValues(alpha: 0.06) : c.onSurface.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))];
  static List<BoxShadow> elevated(NanoColors c) => [BoxShadow(color: c is NanoDarkColors ? c.primary.withValues(alpha: 0.12) : c.onSurface.withValues(alpha: 0.08), blurRadius: 16, offset: const Offset(0, 4))];
  static List<BoxShadow> glow(NanoColors c, Color color) => [BoxShadow(color: color.withValues(alpha: 0.15), blurRadius: 12, spreadRadius: 2)];
}

/// ── ThemeExtension for semantic colors ──
class NanoThemeExtension extends ThemeExtension<NanoThemeExtension> {
  final NanoColors colors;
  NanoThemeExtension({required this.colors});

  @override
  ThemeExtension<NanoThemeExtension> copyWith({NanoColors? colors}) =>
      NanoThemeExtension(colors: colors ?? this.colors);

  @override
  ThemeExtension<NanoThemeExtension> lerp(ThemeExtension<NanoThemeExtension>? other, double t) => this;

  static NanoThemeExtension of(BuildContext context) =>
      Theme.of(context).extension<NanoThemeExtension>()!;
}
