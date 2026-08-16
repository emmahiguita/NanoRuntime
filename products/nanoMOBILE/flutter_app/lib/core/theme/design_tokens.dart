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
  Color get accent;      // Cyan marca Nano (bordes, títulos de tabla)
  Color get onAccent;    // Texto/icono sobre fondos accent (navy, alto contraste)
  Color get danger;      // Errores custom (más vivo que error)
  Color get codeBlockBg; // Fondo bloques de código markdown
  Color get quoteBg;     // Fondo blockquote
  Color get terminalBg;
  Color get terminalGreen;
  
  // Glassmorphism tokens (solo modo claro)
  Color get glassSurface;
  Color get glassBorder;
  Color get glassOverlay;
}

class NanoDarkColors implements NanoColors {
  @override final primary = const Color(0xFF00E676); // Verde brillante para alto contraste
  @override final primaryContainer = const Color(0xFF1A4D2E); // Más visible
  @override final onPrimaryContainer = const Color(0xFFB9F6CA);
  @override final secondary = const Color(0xFF38BDF8); // Azul cielo
  @override final secondaryContainer = const Color(0xFF1E3A5F); // Más visible
  @override final surface = const Color(0xFF0F172A); // Slate 900
  @override final surfaceVariant = const Color(0xFF1E293B); // Slate 800
  @override final background = const Color(0xFF0B1120); // Slate 950 - más profundo
  @override final onSurface = const Color(0xFFF1F5F9); // Slate 100 - mejor contraste
  @override final onSurfaceVariant = const Color(0xFFCBD5E1); // Slate 300 - más legible
  @override final outline = const Color(0xFF64748B); // Slate 500 - más visible
  @override final outlineVariant = const Color(0xFF334155); // Slate 700 - más definido
  @override final success = const Color(0xFF22C55E); // Verde éxito
  @override final warning = const Color(0xFFF59E0B); // Amarillo advertencia
  @override final error = const Color(0xFFEF4444); // Rojo error
  @override final info = const Color(0xFF3B82F6); // Azul información
  @override final tertiary = const Color(0xFFA855F7); // Púrpura terciario
  @override final accent = const Color(0xFF42D9FF); // Cyan marca Nano
  @override final onAccent = const Color(0xFF062A3A); // Navy profundo sobre cyan
  @override final danger = const Color(0xFFFF5C6C); // Rojo coral vivo
  @override final codeBlockBg = const Color(0xFF040E1A); // Azul casi negro
  @override final quoteBg = const Color(0xFF003040); // Teal profundo
  @override final terminalBg = const Color(0xFF0B1120); // Coincide con background
  @override final terminalGreen = const Color(0xFF22C55E); // Verde terminal
  
  // Glassmorphism no aplicado en modo oscuro (usa valores por defecto)
  @override final glassSurface = const Color(0x00000000); // Transparente
  @override final glassBorder = const Color(0x00000000); // Transparente
  @override final glassOverlay = const Color(0x00000000); // Transparente
}

class NanoLightColors implements NanoColors {
  @override final primary = const Color(0xFF0284C7); // Sky 600 — cyan acción (bordes/botones)
  @override final primaryContainer = const Color(0xFFE0F2FE); // Sky 100 — contenedor cyan claro
  @override final onPrimaryContainer = const Color(0xFF075985); // Sky 800 — texto oscuro sobre cyan
  @override final secondary = const Color(0xFF0EA5E9); // Sky 500 — secundario cyan
  @override final secondaryContainer = const Color(0xFFE0F2FE); // Sky 100
  @override final surface = const Color(0xFFFFFFFF); // Blanco puro
  @override final surfaceVariant = const Color(0xFFF8FAFC); // Slate 50 - fondo cards
  @override final background = const Color(0xFFFCFCFD); // Blanco casi puro
  @override final onSurface = const Color(0xFF0F172A); // Slate 900 - alto contraste
  @override final onSurfaceVariant = const Color(0xFF475569); // Slate 600 - legible
  @override final outline = const Color(0xFF7DD3FC); // Sky 300 — LÍNEA DE BORDE CYAN
  @override final outlineVariant = const Color(0xFFBAE6FD); // Sky 200 — cyan muy sutil
  @override final success = const Color(0xFF059669); // Esmeralda 600 — semántico "ok" (no es gama decorativa)
  @override final warning = const Color(0xFFB45309); // Ámbar 700 — semántico
  @override final error = const Color(0xFFEF4444); // Rojo error
  @override final info = const Color(0xFF0284C7); // Cyan información
  @override final tertiary = const Color(0xFF0D9488); // Teal 600 — misma gama cyan (era violeta)
  @override final accent = const Color(0xFF0284C7); // Sky 600 — cyan marca Nano
  @override final onAccent = const Color(0xFF082F49); // Sky 950 - alto contraste sobre cyan
  @override final danger = const Color(0xFFDC2626); // Red 600 - legible sobre blanco
  @override final codeBlockBg = const Color(0xFFF1F5F9); // Slate 100
  @override final quoteBg = const Color(0xFFE0F2FE); // Sky 100 — cita en gama cyan
  @override final terminalBg = const Color(0xFFF8FAFC); // Slate 50 - terminal claro
  @override final terminalGreen = const Color(0xFF047857); // Esmeralda 700 — semántico terminal

  // Glassmorphism tokens (solo modo claro) — bordes cyan
  @override final glassSurface = const Color(0xDDFFFFFF); // Blanco 87% transparente
  @override final glassBorder = const Color(0x4D7DD3FC); // Sky 300 30% — borde cristal CYAN
  @override final glassOverlay = const Color(0x0F0284C7); // Sky 600 6% overlay cyan
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
  static List<BoxShadow> card(NanoColors c) => [
    BoxShadow(
      color: c is NanoDarkColors 
        ? const Color(0xFF000000).withValues(alpha: 0.3) // Sombra oscura en modo oscuro
        : const Color(0xFF000000).withValues(alpha: 0.06), // Sombra muy sutil en modo claro
      blurRadius: 8, 
      offset: const Offset(0, 2),
    ),
    if (c is! NanoDarkColors) // Sombra secundaria solo en modo claro para profundidad
      BoxShadow(
        color: const Color(0xFF000000).withValues(alpha: 0.04),
        blurRadius: 1,
        offset: const Offset(0, 1),
      ),
  ];
  
  static List<BoxShadow> elevated(NanoColors c) => [
    BoxShadow(
      color: c is NanoDarkColors 
        ? const Color(0xFF000000).withValues(alpha: 0.4) // Sombra más oscura en modo oscuro
        : const Color(0xFF000000).withValues(alpha: 0.10), // Sombra profesional en modo claro
      blurRadius: 16, 
      offset: const Offset(0, 4),
    ),
    if (c is! NanoDarkColors) // Sombra secundaria en modo claro
      BoxShadow(
        color: const Color(0xFF000000).withValues(alpha: 0.05),
        blurRadius: 4,
        offset: const Offset(0, 2),
      ),
  ];
  
  static List<BoxShadow> glow(NanoColors c, Color color) => [
    BoxShadow(
      color: color.withValues(alpha: c is NanoDarkColors ? 0.4 : 0.25), // Glow ajustado por tema
      blurRadius: 12, 
      spreadRadius: 2,
    ),
  ];
  
  /// Sombra profesional para floating action buttons
  static List<BoxShadow> fab(NanoColors c) => [
    BoxShadow(
      color: c is NanoDarkColors 
        ? const Color(0xFF000000).withValues(alpha: 0.5)
        : const Color(0xFF000000).withValues(alpha: 0.15),
      blurRadius: 20,
      offset: const Offset(0, 6),
    ),
    if (c is! NanoDarkColors)
      BoxShadow(
        color: const Color(0xFF000000).withValues(alpha: 0.08),
        blurRadius: 6,
        offset: const Offset(0, 2),
      ),
  ];
  
  /// Sombra para elementos destacados en modo claro
  static List<BoxShadow> highlight(NanoColors c) => [
    if (c is! NanoDarkColors)
      BoxShadow(
        color: const Color(0xFF0284C7).withValues(alpha: 0.15), // Tinte cyan sutil (era verde)
        blurRadius: 8,
        offset: const Offset(0, 2),
      ),
  ];
  
  /// Sombras específicas para Glassmorphism (modo claro)
  static List<BoxShadow> glass(NanoColors c) => [
    if (c is! NanoDarkColors)
      BoxShadow(
        color: const Color(0xFF000000).withValues(alpha: 0.08),
        blurRadius: 16,
        offset: const Offset(0, 4),
      ),
    BoxShadow(
      color: c is NanoDarkColors 
        ? const Color(0xFF000000).withValues(alpha: 0.3)
        : const Color(0xFFFFFFFF).withValues(alpha: 0.3), // Sombra interna blanca para glass
      blurRadius: 2,
      offset: const Offset(0, -1),
      spreadRadius: -1,
    ),
  ];
  
  /// Sombras para elementos glass elevados
  static List<BoxShadow> glassElevated(NanoColors c) => [
    if (c is! NanoDarkColors)
      BoxShadow(
        color: const Color(0xFF000000).withValues(alpha: 0.12),
        blurRadius: 24,
        offset: const Offset(0, 8),
      ),
    BoxShadow(
      color: c is NanoDarkColors 
        ? const Color(0xFF000000).withValues(alpha: 0.4)
        : const Color(0xFFFFFFFF).withValues(alpha: 0.4),
      blurRadius: 4,
      offset: const Offset(0, -2),
      spreadRadius: -1,
    ),
  ];
}

/// ── ThemeExtension for semantic colors ──
class NanoThemeExtension extends ThemeExtension<NanoThemeExtension> {
  final NanoColors colors;
  NanoThemeExtension({required this.colors});

  @override
  ThemeExtension<NanoThemeExtension> copyWith({NanoColors? colors}) =>
      NanoThemeExtension(colors: colors ?? this.colors);

  @override
  ThemeExtension<NanoThemeExtension> lerp(ThemeExtension<NanoThemeExtension>? other, double t) {
    if (other is! NanoThemeExtension) return this;
    return NanoThemeExtension(
      colors: _LerpedNanoColors(a: colors, b: other.colors, t: t),
    );
  }

  static NanoThemeExtension of(BuildContext context) =>
      Theme.of(context).extension<NanoThemeExtension>()!;
}

/// Interpolación REAL de cada token para transiciones de tema suaves.
/// Color.lerp con t entre 0 (a) y 1 (b) — sin atajos ni `return this`.
class _LerpedNanoColors implements NanoColors {
  final NanoColors a;
  final NanoColors b;
  final double t;

  _LerpedNanoColors({required this.a, required this.b, required this.t});

  Color _l(Color x, Color y) => Color.lerp(x, y, t)!;

  @override
  Color get primary => _l(a.primary, b.primary);
  @override
  Color get primaryContainer => _l(a.primaryContainer, b.primaryContainer);
  @override
  Color get onPrimaryContainer => _l(a.onPrimaryContainer, b.onPrimaryContainer);
  @override
  Color get secondary => _l(a.secondary, b.secondary);
  @override
  Color get secondaryContainer => _l(a.secondaryContainer, b.secondaryContainer);
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
}
