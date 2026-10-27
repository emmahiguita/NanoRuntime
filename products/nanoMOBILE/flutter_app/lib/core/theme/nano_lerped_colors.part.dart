part of 'design_tokens.dart';

/// Interpolador de colores ópticos Nano AI para transiciones fluidas a 60/120 FPS.
///
/// - QUÉ HACE: Realiza interpolación lineal (lerp) continua entre dos paletas [NanoColors].
/// - CÓMO FUNCIONA: Cuenta con camino rápido (fast-path) para t=0 y t=1 eliminando cálculos
///   innecesarios. Para valores intermedios (0 < t < 1), interpola cada canal alfa y RGB
///   vía [Color.lerp] en tiempo de renderizado con cero cuellos de botella.
/// - POR QUÉ: Permite transiciones de tema suaves (cross-fade adaptativo) sin parpadeos visuales
///   ni saltos abruptos de color.
class _LerpedNanoColors implements NanoColors {
  final NanoColors a;
  final NanoColors b;
  final double t;

  _LerpedNanoColors({required this.a, required this.b, required this.t});

  Color _l(Color x, Color y) {
    if (t <= 0.0) return x;
    if (t >= 1.0) return y;
    return Color.lerp(x, y, t) ?? x;
  }

  double _d(double x, double y) {
    if (t <= 0.0) return x;
    if (t >= 1.0) return y;
    return x + (y - x) * t;
  }

  // --- Roles Principales ---
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

  // --- Glassmorphism ---
  @override
  Color get glassSurface => _l(a.glassSurface, b.glassSurface);
  @override
  Color get glassBorder => _l(a.glassBorder, b.glassBorder);
  @override
  Color get glassOverlay => _l(a.glassOverlay, b.glassOverlay);

  // --- Metálicos y Gradientes ---
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

  // --- Capas de Elevación ---
  @override
  Color get backgroundPrimary => _l(a.backgroundPrimary, b.backgroundPrimary);
  @override
  Color get backgroundSecondary => _l(a.backgroundSecondary, b.backgroundSecondary);
  @override
  Color get backgroundElevated => _l(a.backgroundElevated, b.backgroundElevated);
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

  // --- Factores de Opacidad ---
  @override
  double get glassLow => _d(a.glassLow, b.glassLow);
  @override
  double get glassMedium => _d(a.glassMedium, b.glassMedium);
  @override
  double get glassStrong => _d(a.glassStrong, b.glassStrong);
  @override
  double get glassOpaque => _d(a.glassOpaque, b.glassOpaque);

  // --- Tipografía ---
  @override
  Color get textPrimary => _l(a.textPrimary, b.textPrimary);
  @override
  Color get textSecondary => _l(a.textSecondary, b.textSecondary);
  @override
  Color get textTertiary => _l(a.textTertiary, b.textTertiary);
  @override
  Color get textDisabled => _l(a.textDisabled, b.textDisabled);

  // --- Acentos Cromáticos ---
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

  // --- Refracciones y Reflejos ---
  @override
  Color get iceReflection => _l(a.iceReflection, b.iceReflection);
  @override
  Color get silverReflection => _l(a.silverReflection, b.silverReflection);
  @override
  Color get pearlReflection => _l(a.pearlReflection, b.pearlReflection);
  @override
  Color get warmReflection => _l(a.warmReflection, b.warmReflection);
  @override
  Color get lavenderReflection => _l(a.lavenderReflection, b.lavenderReflection);

  // --- Bordes ---
  @override
  Color get borderPrimaryColor => _l(a.borderPrimaryColor, b.borderPrimaryColor);
  @override
  Color get borderSecondaryColor => _l(a.borderSecondaryColor, b.borderSecondaryColor);
  @override
  Color get borderAccentColor => _l(a.borderAccentColor, b.borderAccentColor);

  @override
  bool get isClassicOrange => t < 0.5 ? a.isClassicOrange : b.isClassicOrange;
}
