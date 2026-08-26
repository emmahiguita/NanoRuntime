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
  Color get tertiary;

  // Roles custom del chat (modo claro real)
  Color get accent; // Cyan marca Nano (bordes, títulos de tabla)
  Color get onAccent; // Texto/icono sobre fondos accent (navy, alto contraste)
  Color get danger; // Errores custom (más vivo que error)
  Color get codeBlockBg; // Fondo bloques de código markdown
  Color get quoteBg; // Fondo blockquote
  Color get terminalBg;
  Color get terminalGreen;

  // Glassmorphism tokens (solo modo claro)
  Color get glassSurface;
  Color get glassBorder;
  Color get glassOverlay;

  // --- Glass Metallic Redesign Tokens ---
  Color get bgTop;
  Color get bgMiddle;
  Color get bgBottom;

  Color get glass100;
  Color get glass200;
  Color get glass300;
  Color get glass400;

  Color get metalWhite;
  Color get metalPearl;
  Color get metalSilver;
  Color get metalCool;
  Color get metalSteel;
  Color get metalGraphite;
  Color get metalDark;

  Color get warmReflect1;
  Color get warmReflect2;
  Color get warmReflect3;

  Color get coldReflect1;
  Color get coldReflect2;
  Color get coldReflect3;
  Color get coldReflect4;
  Color get coldReflect5;

  Color get nanoCyan;
  Color get nanoTurquoise;
  Color get nanoBlue;
  Color get nanoViolet;

  // --- New Semantic Light/Dark Palette Tokens ---
  Color get backgroundPrimary;
  Color get backgroundSecondary;
  Color get backgroundElevated;
  Color get backgroundIce;
  Color get backgroundPearl;
  Color get backgroundDeep;
  Color get backgroundNavy;

  Color get glassPrimary;
  Color get glassSecondary;
  Color get glassGraphite;
  Color get glassBlue;

  double get glassLow;
  double get glassMedium;
  double get glassStrong;
  double get glassOpaque;

  Color get textPrimary;
  Color get textSecondary;
  Color get textTertiary;
  Color get textDisabled;

  Color get accentCyan;
  Color get accentMint;
  Color get accentSky;
  Color get accentBlue;
  Color get accentLavender;

  Color get iceReflection;
  Color get silverReflection;
  Color get pearlReflection;
  Color get warmReflection;
  Color get lavenderReflection;

  Color get borderPrimaryColor;
  Color get borderSecondaryColor;
  Color get borderAccentColor;
}

class NanoDarkColors implements NanoColors {
  @override
  final primary = const Color(0xFF00E676); // Verde brillante para alto contraste
  @override
  final primaryContainer = const Color(0xFF1A4D2E); // Más visible
  @override
  final onPrimaryContainer = const Color(0xFFB9F6CA);
  @override
  final secondary = const Color(0xFF38BDF8); // Azul cielo
  @override
  final secondaryContainer = const Color(0xFF1E3A5F); // Más visible
  @override
  final surface = const Color(0xFF0F172A); // Slate 900
  @override
  final surfaceVariant = const Color(0xFF1E293B); // Slate 800
  @override
  final background = const Color(0xFF020711); // backgroundPrimary
  @override
  final onSurface = const Color(0xFFF5F7FA); // textPrimary
  @override
  final onSurfaceVariant = const Color(0xFFA8B3C2); // textSecondary
  @override
  final outline = const Color(0xFF64748B); // Slate 500 - más visible
  @override
  final outlineVariant = const Color(0xFF334155); // Slate 700 - más definido
  @override
  final success = const Color(0xFF49E0BC); // Mint/success
  @override
  final warning = const Color(0xFFF1BC69); // Amarillo warning
  @override
  final error = const Color(0xFFFF7782); // Rojo error
  @override
  final info = const Color(0xFF6BC4FF); // Azul información
  @override
  final tertiary = const Color(0xFFA855F7); // Púrpura terciario
  @override
  final accent = const Color(0xFF42F5E3); // Cyan marca Nano
  @override
  final onAccent = const Color(0xFF062A3A); // Navy profundo sobre cyan
  @override
  final danger = const Color(0xFFFF5C6C); // Rojo coral vivo
  @override
  final codeBlockBg = const Color(0xFF040E1A); // Azul casi negro
  @override
  final quoteBg = const Color(0xFF003040); // Teal profundo
  @override
  final terminalBg = const Color(0xFF0B1120); // Coincide con background
  @override
  final terminalGreen = const Color(0xFF22C55E); // Verde terminal

  // Glassmorphism no aplicado en modo oscuro (usa valores por defecto)
  @override
  final glassSurface = const Color(0x00000000); // Transparente
  @override
  final glassBorder = const Color(0x00000000); // Transparente
  @override
  final glassOverlay = const Color(0x00000000); // Transparente

  // --- Glass Metallic Redesign Tokens ---
  @override
  final bgTop = const Color(0xFF020711); // backgroundPrimary
  @override
  final bgMiddle = const Color(0xFF050C16); // backgroundSecondary
  @override
  final bgBottom = const Color(0xFF08131F); // backgroundElevated

  @override
  final glass100 = const Color(0xFF0B1825);
  @override
  final glass200 = const Color(0xFF102130);
  @override
  final glass300 = const Color(0xFF141D28);
  @override
  final glass400 = const Color(0xFF0B1E30);

  @override
  final metalWhite = const Color(0xFFFFFFFF);
  @override
  final metalPearl = const Color(0xFFF5F6FA);
  @override
  final metalSilver = const Color(0xFFD9DDE5);
  @override
  final metalCool = const Color(0xFF5A6778);
  @override
  final metalSteel = const Color(0xFF9BA5B5);
  @override
  final metalGraphite = const Color(0xFF3F4856);
  @override
  final metalDark = const Color(0xFF141B25);

  @override
  final warmReflect1 = const Color(0xFFFFF1D6);
  @override
  final warmReflect2 = const Color(0xFFEED8B6);
  @override
  final warmReflect3 = const Color(0xFFFFD9A6);

  @override
  final coldReflect1 = const Color(0xFFBCEBFF);
  @override
  final coldReflect2 = const Color(0xFF76DFFF);
  @override
  final coldReflect3 = const Color(0xFF57B8FF);
  @override
  final coldReflect4 = const Color(0xFF6787FF);
  @override
  final coldReflect5 = const Color(0xFF8073FF);

  @override
  final nanoCyan = const Color(0xFF42F5E3);
  @override
  final nanoTurquoise = const Color(0xFF28D7CF);
  @override
  final nanoBlue = const Color(0xFF4A8FFF);
  @override
  final nanoViolet = const Color(0xFF7168FF);

  // --- New Semantic Dark Palette Tokens ---
  @override
  final backgroundPrimary = const Color(0xFF020711);
  @override
  final backgroundSecondary = const Color(0xFF050C16);
  @override
  final backgroundElevated = const Color(0xFF08131F);
  @override
  final backgroundDeep = const Color(0xFF01040A);
  @override
  final backgroundNavy = const Color(0xFF071522);
  @override
  final backgroundIce = const Color(0xFF0B1825);
  @override
  final backgroundPearl = const Color(0xFF141D28);

  @override
  final glassPrimary = const Color(0xFF0B1825);
  @override
  final glassSecondary = const Color(0xFF102130);
  @override
  final glassGraphite = const Color(0xFF141D28);
  @override
  final glassBlue = const Color(0xFF0B1E30);

  @override
  final glassLow = 0.32;
  @override
  final glassMedium = 0.46;
  @override
  final glassStrong = 0.62;
  @override
  final glassOpaque = 0.78;

  @override
  final textPrimary = const Color(0xFFF5F7FA);
  @override
  final textSecondary = const Color(0xFFA8B3C2);
  @override
  final textTertiary = const Color(0xFF737F91);
  @override
  final textDisabled = const Color(0xFF526071);

  @override
  final accentCyan = const Color(0xFF42F5E3);
  @override
  final accentMint = const Color(0xFF35E1C3);
  @override
  final accentSky = const Color(0xFF59C8FF);
  @override
  final accentBlue = const Color(0xFF638DFF);
  @override
  final accentLavender = const Color(0xFF9184FF);

  @override
  final iceReflection = const Color(0xFFA9E7FF);
  @override
  final silverReflection = const Color(0xFFB9C6D3);
  @override
  final pearlReflection = const Color(0xFFF5F7FA);
  @override
  final warmReflection = const Color(0xFFF1D7B6);
  @override
  final lavenderReflection = const Color(0xFF9E94FF);

  @override
  final borderPrimaryColor = const Color(0x26FFFFFF); // rgba(255,255,255,0.15)
  @override
  final borderSecondaryColor = const Color(0x2E97A1BF); // rgba(151,170,191,0.18)
  @override
  final borderAccentColor = const Color(0x4042F5E3); // rgba(66,245,227,0.25)
}

class NanoLightColors implements NanoColors {
  @override
  final primary = const Color(0xFF0891B2); // Cyan 600 (oscuro, visible en claro)
  @override
  final primaryContainer = const Color(0xFFEEF5FB); // Canvas Ice
  @override
  final onPrimaryContainer = const Color(0xFF1D2733); // Text Primary
  @override
  final secondary = const Color(0xFF4F46E5); // Indigo 600
  @override
  final secondaryContainer = const Color(0xFFE8EEF5); // Canvas Elevated Gris
  @override
  final surface = const Color(0xFFFFFFFF); // Blanco puro
  @override
  final surfaceVariant = const Color(0xFFE8EEF5); // Gris azulado (TextField visible)
  @override
  final background = const Color(0xFFF7F9FC); // Canvas Primary
  @override
  final onSurface = const Color(0xFF1D2733); // Text Primary
  @override
  final onSurfaceVariant = const Color(0xFF637083); // Text Secondary
  @override
  final outline = const Color(0xFFA8B4C2); // Metal Silver visible
  @override
  final outlineVariant = const Color(0xFFEEF5FB); // Canvas Ice
  @override
  final success = const Color(0xFF0F9E6E); // Esmeralda 600 (contraste en claro)
  @override
  final warning = const Color(0xFFA16207); // Ámbar 700
  @override
  final error = const Color(0xFFD6455A); // Coral 600 (rojo visible)
  @override
  final info = const Color(0xFF0369A1); // Sky 700
  @override
  final tertiary = const Color(0xFF6D28D9); // Violeta 700
  @override
  final accent = const Color(0xFF0891B2); // Cyan 600
  @override
  final onAccent = const Color(0xFFF5FAFC); // Casi blanco sobre acento oscuro
  @override
  final danger = const Color(0xFFD6455A); // Coral 600
  @override
  final codeBlockBg = const Color(0xFFF2F6FA); // Canvas Secondary
  @override
  final quoteBg = const Color(0xFFEFF7FC); // Glass Ice
  @override
  final terminalBg = const Color(0xFFF8FAFC); // Slate 50
  @override
  final terminalGreen = const Color(0xFF047857); // Esmeralda 700

  // Glassmorphism tokens (solo modo claro) — bordes ópticos metálicos
  @override
  final glassSurface = const Color(0xCCFFFFFF); // Blanco 80% translúcido
  @override
  final glassBorder = const Color(0x408B97A8); // Metal Steel suave (más definido)
  @override
  final glassOverlay = const Color(0x0D0891B2); // Cyan 5% overlay óptico

  // --- Glass Metallic Redesign Tokens ---
  @override
  final bgTop = const Color(0xFFF7F9FC); // Canvas Primary
  @override
  final bgMiddle = const Color(0xFFF2F6FA); // Canvas Secondary
  @override
  final bgBottom = const Color(0xFFEEF5FB); // Canvas Ice

  @override
  final glass100 = const Color(0xFFEFF7FC); // Glass Ice
  @override
  final glass200 = const Color(0xFFFFFFFF); // Glass White
  @override
  final glass300 = const Color(0xFFEDF5FF); // Glass Blue
  @override
  final glass400 = const Color(0xFFF8FAFC); // Glass Pearl

  @override
  final metalWhite = const Color(0xFFFFFFFF);
  @override
  final metalPearl = const Color(0xFFF8FAFC);
  @override
  final metalSilver = const Color(0xFFDCE5ED);
  @override
  final metalCool = const Color(0xFFB7C6D4);
  @override
  final metalSteel = const Color(0xFF9EADBC);
  @override
  final metalGraphite = const Color(0xFF3F4856);
  @override
  final metalDark = const Color(0xFF141B25);

  @override
  final warmReflect1 = const Color(0xFFF1E5D8); // Metal Warm
  @override
  final warmReflect2 = const Color(0xFFEED8B6);
  @override
  final warmReflect3 = const Color(0xFFFFD9A6);

  @override
  final coldReflect1 = const Color(0xFFBCEBFF);
  @override
  final coldReflect2 = const Color(0xFF76DFFF);
  @override
  final coldReflect3 = const Color(0xFF57B8FF);
  @override
  final coldReflect4 = const Color(0xFF6787FF);
  @override
  final coldReflect5 = const Color(0xFF8073FF);

  @override
  final nanoCyan = const Color(0xFF0891B2);
  @override
  final nanoTurquoise = const Color(0xFF0D9488);
  @override
  final nanoBlue = const Color(0xFF4F46E5);
  @override
  final nanoViolet = const Color(0xFF6D28D9);

  // --- Canonical Semantic Light Palette Tokens ---
  @override
  final backgroundPrimary = const Color(0xFFF7F9FC); // Canvas Base Home
  @override
  final backgroundSecondary = const Color(0xFFF2F6FA); // Canvas Secondary
  @override
  final backgroundElevated = const Color(0xFFFFFFFF); // Canvas Elevated
  @override
  final backgroundIce = const Color(0xFFEEF5FB); // Canvas Ice
  @override
  final backgroundPearl = const Color(0xFFF8FAFC);
  @override
  final backgroundDeep = const Color(0xFFE9F0F8);
  @override
  final backgroundNavy = const Color(0xFFDCE5ED);

  @override
  final glassPrimary = const Color(0xFFFFFFFF); // Glass White Puro
  @override
  final glassSecondary = const Color(0xFFF8FAFC); // Glass Pearl
  @override
  final glassGraphite = const Color(0xFFEFF7FC); // Glass Ice
  @override
  final glassBlue = const Color(0xFFEDF5FF); // Glass Blue

  @override
  final glassLow = 0.36;
  @override
  final glassMedium = 0.50;
  @override
  final glassStrong = 0.64;
  @override
  final glassOpaque = 0.78;

  @override
  final textPrimary = const Color(0xFF1D2733); // Text Primary
  @override
  final textSecondary = const Color(0xFF637083); // Text Secondary
  @override
  final textTertiary = const Color(0xFF8B97A8); // Text Tertiary
  @override
  final textDisabled = const Color(0xFFB6C0CB); // Text Disabled

  @override
  final accentCyan = const Color(0xFF0891B2);
  @override
  final accentMint = const Color(0xFF059669);
  @override
  final accentSky = const Color(0xFF0284C7);
  @override
  final accentBlue = const Color(0xFF4F46E5);
  @override
  final accentLavender = const Color(0xFF6D28D9);

  @override
  final iceReflection = const Color(0xFFEFF7FC);
  @override
  final silverReflection = const Color(0xFFDCE5ED);
  @override
  final pearlReflection = const Color(0xFFFFFFFF);
  @override
  final warmReflection = const Color(0xFFF1E5D8);
  @override
  final lavenderReflection = const Color(0xFFA89AF8);

  @override
  final borderPrimaryColor = const Color(0xF5FFFFFF); // Blanco brillante
  @override
  final borderSecondaryColor = const Color(0x40DCE5ED); // Línea metálica suave (Silver)
  @override
  final borderAccentColor = const Color(0x6055DCE8); // Cyan borde reflectivo
}

class _LerpedNanoColors implements NanoColors {
  final NanoColors a;
  final NanoColors b;
  final double t;

  _LerpedNanoColors({required this.a, required this.b, required this.t});

  Color _l(Color x, Color y) => Color.lerp(x, y, t)!;
  double _d(double x, double y) => x + (y - x) * t;

  @override
  Color get primary => _l(a.primary, b.primary);
  @override
  Color get primaryContainer => _l(a.primaryContainer, b.primaryContainer);
  @override
  Color get onPrimaryContainer =>
      _l(a.onPrimaryContainer, b.onPrimaryContainer);
  @override
  Color get secondary => _l(a.secondary, b.secondary);
  @override
  Color get secondaryContainer =>
      _l(a.secondaryContainer, b.secondaryContainer);
  @override
  Color get surface => _l(a.surface, b.surface);
  @override
  Color get surfaceVariant => _l(a.surfaceVariant, b.surfaceVariant);
  @override
  Color get background => _l(a.background, b.background);
  @override
  Color get onSurface => _l(a.onSurface, b.onSurface);
  @override
  Color get onSurfaceVariant => _l(a.onSurfaceVariant, b.onSurfaceVariant);
  @override
  Color get outline => _l(a.outline, b.outline);
  @override
  Color get outlineVariant => _l(a.outlineVariant, b.outlineVariant);
  @override
  Color get success => _l(a.success, b.success);
  @override
  Color get warning => _l(a.warning, b.warning);
  @override
  Color get error => _l(a.error, b.error);
  @override
  Color get info => _l(a.info, b.info);
  @override
  Color get tertiary => _l(a.tertiary, b.tertiary);
  @override
  Color get accent => _l(a.accent, b.accent);
  @override
  Color get onAccent => _l(a.onAccent, b.onAccent);
  @override
  Color get danger => _l(a.danger, b.danger);
  @override
  Color get codeBlockBg => _l(a.codeBlockBg, b.codeBlockBg);
  @override
  Color get quoteBg => _l(a.quoteBg, b.quoteBg);
  @override
  Color get terminalBg => _l(a.terminalBg, b.terminalBg);
  @override
  Color get terminalGreen => _l(a.terminalGreen, b.terminalGreen);
  @override
  Color get glassSurface => _l(a.glassSurface, b.glassSurface);
  @override
  Color get glassBorder => _l(a.glassBorder, b.glassBorder);
  @override
  Color get glassOverlay => _l(a.glassOverlay, b.glassOverlay);

  // --- Glass Metallic Redesign Tokens ---
  @override
  Color get bgTop => _l(a.bgTop, b.bgTop);
  @override
  Color get bgMiddle => _l(a.bgMiddle, b.bgMiddle);
  @override
  Color get bgBottom => _l(a.bgBottom, b.bgBottom);
  @override
  Color get glass100 => _l(a.glass100, b.glass100);
  @override
  Color get glass200 => _l(a.glass200, b.glass200);
  @override
  Color get glass300 => _l(a.glass300, b.glass300);
  @override
  Color get glass400 => _l(a.glass400, b.glass400);
  @override
  Color get metalWhite => _l(a.metalWhite, b.metalWhite);
  @override
  Color get metalPearl => _l(a.metalPearl, b.metalPearl);
  @override
  Color get metalSilver => _l(a.metalSilver, b.metalSilver);
  @override
  Color get metalCool => _l(a.metalCool, b.metalCool);
  @override
  Color get metalSteel => _l(a.metalSteel, b.metalSteel);
  @override
  Color get metalGraphite => _l(a.metalGraphite, b.metalGraphite);
  @override
  Color get metalDark => _l(a.metalDark, b.metalDark);
  @override
  Color get warmReflect1 => _l(a.warmReflect1, b.warmReflect1);
  @override
  Color get warmReflect2 => _l(a.warmReflect2, b.warmReflect2);
  @override
  Color get warmReflect3 => _l(a.warmReflect3, b.warmReflect3);
  @override
  Color get coldReflect1 => _l(a.coldReflect1, b.coldReflect1);
  @override
  Color get coldReflect2 => _l(a.coldReflect2, b.coldReflect2);
  @override
  Color get coldReflect3 => _l(a.coldReflect3, b.coldReflect3);
  @override
  Color get coldReflect4 => _l(a.coldReflect4, b.coldReflect4);
  @override
  Color get coldReflect5 => _l(a.coldReflect5, b.coldReflect5);
  @override
  Color get nanoCyan => _l(a.nanoCyan, b.nanoCyan);
  @override
  Color get nanoTurquoise => _l(a.nanoTurquoise, b.nanoTurquoise);
  @override
  Color get nanoBlue => _l(a.nanoBlue, b.nanoBlue);
  @override
  Color get nanoViolet => _l(a.nanoViolet, b.nanoViolet);

  // --- New Semantic Palette Tokens ---
  @override
  Color get backgroundPrimary => _l(a.backgroundPrimary, b.backgroundPrimary);
  @override
  Color get backgroundSecondary =>
      _l(a.backgroundSecondary, b.backgroundSecondary);
  @override
  Color get backgroundElevated =>
      _l(a.backgroundElevated, b.backgroundElevated);
  @override
  Color get backgroundIce => _l(a.backgroundIce, b.backgroundIce);
  @override
  Color get backgroundPearl => _l(a.backgroundPearl, b.backgroundPearl);
  @override
  Color get backgroundDeep => _l(a.backgroundDeep, b.backgroundDeep);
  @override
  Color get backgroundNavy => _l(a.backgroundNavy, b.backgroundNavy);

  @override
  Color get glassPrimary => _l(a.glassPrimary, b.glassPrimary);
  @override
  Color get glassSecondary => _l(a.glassSecondary, b.glassSecondary);
  @override
  Color get glassGraphite => _l(a.glassGraphite, b.glassGraphite);
  @override
  Color get glassBlue => _l(a.glassBlue, b.glassBlue);

  @override
  double get glassLow => _d(a.glassLow, b.glassLow);
  @override
  double get glassMedium => _d(a.glassMedium, b.glassMedium);
  @override
  double get glassStrong => _d(a.glassStrong, b.glassStrong);
  @override
  double get glassOpaque => _d(a.glassOpaque, b.glassOpaque);

  @override
  Color get textPrimary => _l(a.textPrimary, b.textPrimary);
  @override
  Color get textSecondary => _l(a.textSecondary, b.textSecondary);
  @override
  Color get textTertiary => _l(a.textTertiary, b.textTertiary);
  @override
  Color get textDisabled => _l(a.textDisabled, b.textDisabled);

  @override
  Color get accentCyan => _l(a.accentCyan, b.accentCyan);
  @override
  Color get accentMint => _l(a.accentMint, b.accentMint);
  @override
  Color get accentSky => _l(a.accentSky, b.accentSky);
  @override
  Color get accentBlue => _l(a.accentBlue, b.accentBlue);
  @override
  Color get accentLavender => _l(a.accentLavender, b.accentLavender);

  @override
  Color get iceReflection => _l(a.iceReflection, b.iceReflection);
  @override
  Color get silverReflection => _l(a.silverReflection, b.silverReflection);
  @override
  Color get pearlReflection => _l(a.pearlReflection, b.pearlReflection);
  @override
  Color get warmReflection => _l(a.warmReflection, b.warmReflection);
  @override
  Color get lavenderReflection =>
      _l(a.lavenderReflection, b.lavenderReflection);

  @override
  Color get borderPrimaryColor =>
      _l(a.borderPrimaryColor, b.borderPrimaryColor);
  @override
  Color get borderSecondaryColor =>
      _l(a.borderSecondaryColor, b.borderSecondaryColor);
  @override
  Color get borderAccentColor => _l(a.borderAccentColor, b.borderAccentColor);
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

/// ── Animation Curves ──
class NanoCurves {
  static const easeOut = Curves.easeOutCubic;
  static const easeInOut = Curves.easeInOutCubic;
}

/// ── Shape Tokens (Regla 14: Radios 12, 18, 24, 32, 40) ──
class NanoShapes {
  static const small = BorderRadius.all(Radius.circular(12));
  static const medium = BorderRadius.all(Radius.circular(18));
  static const large = BorderRadius.all(Radius.circular(24));
  static const extraLarge = BorderRadius.all(Radius.circular(32));
  static const hero = BorderRadius.all(Radius.circular(40));
  static const full = BorderRadius.all(Radius.circular(100));
  static const userBubble = BorderRadius.only(
    topLeft: Radius.circular(24),
    topRight: Radius.circular(24),
    bottomLeft: Radius.circular(24),
    bottomRight: Radius.circular(6),
  );
  static const aiBubble = BorderRadius.only(
    topLeft: Radius.circular(24),
    topRight: Radius.circular(24),
    bottomLeft: Radius.circular(6),
    bottomRight: Radius.circular(24),
  );
}

/// ── 1. ORGANIZACIÓN DE SOMBRAS (NanoShadows) ──
abstract final class NanoShadows {
  /// Sombra ambiental óptica (Multi-capa: difusa + contacto + acento sutil)
  static List<BoxShadow> ambient(
    NanoColors colors, {
    double depth = 1.0,
    Color? accent,
  }) {
    final isDark = colors is NanoDarkColors;
    final shadowBase = isDark
        ? const Color(0xFF000000)
        : const Color(0xFF7F9AB5);
    final primaryOpacity = isDark
        ? (0.28 + (0.22 * depth)).clamp(0.0, 0.70)
        : (0.06 + (0.06 * depth)).clamp(0.0, 0.20);

    return [
      // Capa 1: Sombra difusa principal (iluminación ambiental)
      BoxShadow(
        color: shadowBase.withValues(alpha: primaryOpacity),
        blurRadius: 24.0 + (18.0 * depth),
        offset: Offset(0, 10.0 * depth),
        spreadRadius: isDark ? 0.0 : -2.0,
      ),
      // Capa 2: Sombra de contacto / proximidad
      BoxShadow(
        color: shadowBase.withValues(alpha: isDark ? 0.20 : 0.04),
        blurRadius: 6.0 + (4.0 * depth),
        offset: Offset(0, 2.0 * depth),
      ),
      // Capa 3: Resplandor de acento opcional (solo modo oscuro)
      if (isDark && accent != null)
        BoxShadow(
          color: accent.withValues(alpha: 0.04 * depth.clamp(0.5, 1.5)),
          blurRadius: 28.0 * depth,
          spreadRadius: -4.0,
        ),
    ];
  }

  /// Sombra para botones y controles interactivos
  static List<BoxShadow> control(
    NanoColors colors, {
    bool isPressed = false,
    Color? accent,
  }) {
    if (isPressed) {
      return [
        BoxShadow(
          color:
              (colors is NanoDarkColors
                      ? const Color(0xFF000000)
                      : const Color(0xFF7F9AB5))
                  .withValues(alpha: 0.08),
          blurRadius: 4,
          offset: const Offset(0, 2),
        ),
      ];
    }
    return ambient(colors, depth: 0.6, accent: accent);
  }

  static List<BoxShadow> card(NanoColors c) => [
    BoxShadow(
      color: c is NanoDarkColors
          ? const Color(0xFF000000).withValues(alpha: 0.3)
          : const Color(0xFF7F9AB5).withValues(alpha: 0.08),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
    if (c is! NanoDarkColors)
      BoxShadow(
        color: const Color(0xFF7F9AB5).withValues(alpha: 0.04),
        blurRadius: 2,
        offset: const Offset(0, 1),
      ),
  ];

  static List<BoxShadow> elevated(NanoColors c) => [
    BoxShadow(
      color: c is NanoDarkColors
          ? const Color(0xFF000000).withValues(alpha: 0.4)
          : const Color(0xFF7F9AB5).withValues(alpha: 0.12),
      blurRadius: 20,
      offset: const Offset(0, 8),
    ),
    if (c is! NanoDarkColors)
      BoxShadow(
        color: const Color(0xFF7F9AB5).withValues(alpha: 0.06),
        blurRadius: 4,
        offset: const Offset(0, 2),
      ),
  ];

  static List<BoxShadow> glow(NanoColors c, Color color) => [
    BoxShadow(
      color: color.withValues(alpha: c is NanoDarkColors ? 0.35 : 0.20),
      blurRadius: 16,
      spreadRadius: 1,
    ),
  ];

  static List<BoxShadow> fab(NanoColors c) => [
    BoxShadow(
      color: c is NanoDarkColors
          ? const Color(0xFF000000).withValues(alpha: 0.5)
          : const Color(0xFF7F9AB5).withValues(alpha: 0.16),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
    if (c is! NanoDarkColors)
      BoxShadow(
        color: const Color(0xFF7F9AB5).withValues(alpha: 0.08),
        blurRadius: 6,
        offset: const Offset(0, 2),
      ),
  ];

  static List<BoxShadow> highlight(NanoColors c) => [
    if (c is! NanoDarkColors)
      BoxShadow(
        color: const Color(0xFF0284C7).withValues(alpha: 0.15),
        blurRadius: 8,
        offset: const Offset(0, 2),
      ),
  ];

  static List<BoxShadow> glass(NanoColors c) => ambient(c, depth: 0.8);
  static List<BoxShadow> glassElevated(NanoColors c) => ambient(c, depth: 1.5);
}

/// ── 2. ORGANIZACIÓN DE LÍNEAS Y BISELES (NanoBorders) ──
abstract final class NanoBorders {
  /// Borde metálico perimetral con refracción cromática continua
  static Gradient metallicRim(
    NanoColors colors, {
    Color? accent,
    double refractionIntensity = 1.0,
  }) {
    final isDark = colors is NanoDarkColors;
    final accentCol = accent ?? colors.primary;
    final accentOpacity = (isDark ? 0.25 : 0.35) * refractionIntensity;

    return SweepGradient(
      center: Alignment.center,
      startAngle: 0.0,
      endAngle: 6.28318,
      colors: [
        colors.borderPrimaryColor,
        colors.borderSecondaryColor,
        accentCol.withValues(alpha: accentOpacity.clamp(0.0, 1.0)),
        colors.silverReflection.withValues(alpha: isDark ? 0.18 : 0.40),
        colors.borderPrimaryColor,
      ],
      stops: const [0.0, 0.35, 0.60, 0.85, 1.0],
    );
  }

  /// Bisel de luz especular superior-izquierda a inferior-derecha
  static Gradient specularChamfer(NanoColors colors) {
    final isDark = colors is NanoDarkColors;
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        colors.borderPrimaryColor.withValues(alpha: isDark ? 0.30 : 0.85),
        colors.borderSecondaryColor.withValues(alpha: isDark ? 0.10 : 0.25),
      ],
    );
  }

  /// Borde fino estructural (hairline)
  static Border hairline(NanoColors colors, {double opacity = 1.0}) {
    return Border.all(
      color: colors.borderSecondaryColor.withValues(
        alpha: (colors.borderSecondaryColor.a * opacity).clamp(0.0, 1.0),
      ),
      width: 0.8,
    );
  }
}

/// ── 3. ORGANIZACIÓN DEL DISEÑO METÁLICO (NanoMetallic) ──
abstract final class NanoMetallic {
  /// Gradiente de titanio / cromo pulido
  static Gradient titanium(NanoColors colors) {
    final isDark = colors is NanoDarkColors;
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: isDark
          ? [
              const Color(0xFF182230),
              const Color(0xFF0F1722),
              const Color(0xFF141D28),
            ]
          : [
              const Color(0xFFFFFFFF),
              const Color(0xFFEEF2F6),
              const Color(0xFFE2E8F0),
            ],
    );
  }

  /// Resplandor de Fresnel en esquina superior izquierda
  static Gradient fresnelGlow(NanoColors colors, {double intensity = 1.0}) {
    final isDark = colors is NanoDarkColors;
    final alpha = (isDark ? 0.08 : 0.14) * intensity;
    return RadialGradient(
      center: Alignment.topLeft,
      radius: 1.3,
      colors: [
        colors.pearlReflection.withValues(alpha: alpha.clamp(0.0, 1.0)),
        Colors.transparent,
      ],
    );
  }
}

/// ── 4. ORGANIZACIÓN DEL EFECTO CRISTAL ÓPTICO (NanoGlass) ──
abstract final class NanoGlass {
  /// Substrato vítreo con gradiente lineal interno
  static Gradient substrate(NanoColors colors, {double opacity = 0.60}) {
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        colors.glassPrimary.withValues(alpha: opacity.clamp(0.0, 1.0)),
        colors.glassSecondary.withValues(
          alpha: (opacity * 0.82).clamp(0.0, 1.0),
        ),
        colors.glassGraphite.withValues(
          alpha: (opacity * 0.90).clamp(0.0, 1.0),
        ),
      ],
    );
  }

  /// Tinte de acento radial en esquina inferior
  static Gradient accentTint(Color accent, {double depth = 1.0}) {
    return RadialGradient(
      center: Alignment.bottomRight,
      radius: 1.4,
      colors: [
        accent.withValues(alpha: (0.05 * depth).clamp(0.0, 0.20)),
        Colors.transparent,
      ],
    );
  }

  /// Haz de brillo especular diagonal
  static Gradient specularSheen(NanoColors colors, {double intensity = 1.0}) {
    return LinearGradient(
      colors: [
        Colors.transparent,
        colors.iceReflection.withValues(
          alpha: (0.03 * intensity).clamp(0.0, 0.15),
        ),
        colors.pearlReflection.withValues(
          alpha: (0.09 * intensity).clamp(0.0, 0.25),
        ),
        Colors.transparent,
      ],
      stops: const [0.0, 0.45, 0.55, 1.0],
    );
  }
}

/// ── ThemeExtension for semantic colors ──
class NanoThemeExtension extends ThemeExtension<NanoThemeExtension> {
  final NanoColors colors;
  NanoThemeExtension({required this.colors});

  @override
  ThemeExtension<NanoThemeExtension> copyWith({NanoColors? colors}) =>
      NanoThemeExtension(colors: colors ?? this.colors);

  @override
  ThemeExtension<NanoThemeExtension> lerp(
    ThemeExtension<NanoThemeExtension>? other,
    double t,
  ) {
    if (other is! NanoThemeExtension) return this;
    return NanoThemeExtension(
      colors: _LerpedNanoColors(a: colors, b: other.colors, t: t),
    );
  }

  static NanoThemeExtension of(BuildContext context) =>
      Theme.of(context).extension<NanoThemeExtension>()!;
}

class NanoRadius {
  static const double small = 12.0;
  static const double medium = 18.0;
  static const double large = 26.0;
  static const double xLarge = 34.0;
  static const double hero = 40.0;
}

/// Colores de TEXTO legibles derivados de acentos semánticos.
///
/// Los acentos del tema claro (accentMint/Sky/Lavender/Cyan/Blue, warning,
/// error) son pastel: sobre superficies blancas su contraste WCAG es ~1.6–2.5:1
/// (AA exige ≥4.5:1 para texto pequeño). Usados como color de fuente en chips,
/// badges y etiquetas producen texto casi invisible (mint blanquecino, azul
/// cielo, lila). Este helper devuelve la variante oscura del MISMO tono con
/// contraste AA, sin tocar los acentos originales que pintan bordes/glows/fondos.
abstract final class NanoTextColors {
  /// Contraste WCAG entre dos colores opacos (0..21).
  static double _contrast(Color a, Color b) {
    final la = a.computeLuminance();
    final lb = b.computeLuminance();
    final lighter = la > lb ? la : lb;
    final darker = la > lb ? lb : la;
    return (lighter + 0.05) / (darker + 0.05);
  }

  /// Devuelve [accent] si ya es legible sobre [colors.backgroundPrimary]; si
  /// no, lo oscurece (modo claro) o aclara (modo oscuro) hasta ≥4.5:1,
  /// preservando el tono. Los colores de marca ya saturados se devuelven
  /// intactos (pasan el umbral).
  static Color forText(Color accent, NanoColors colors) {
    final bg = colors.backgroundPrimary;
    if (_contrast(accent, bg) >= 4.5) return accent;
    final target = colors is NanoDarkColors
        ? const Color(0xFFFFFFFF)
        : const Color(0xFF0B1220);
    var t = 0.15;
    while (t < 1.0) {
      final candidate = Color.lerp(accent, target, t)!;
      if (_contrast(candidate, bg) >= 4.5) return candidate;
      t += 0.15;
    }
    return target;
  }
}
