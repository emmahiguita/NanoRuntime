part of 'design_tokens.dart';

/// Identidad Modo Clásico Claro: Blanco y Azul profesional.
///
/// - QUÉ HACE: Provee una alternativa clara con tonos azules tradicionales corporativos.
/// - CÓMO FUNCIONA: Asigna primario azul royal (#1D6FE8) sobre canvas blanco (#FFFFFF)
///   y fondos secundarios (#EFF6FF), manteniendo contraste AA en todos los textos.
/// - POR QUÉ: Ofrece una identidad visual clásica para entornos empresariales tradicionales.
class NanoClassicLightColors implements NanoColors {
  const NanoClassicLightColors();

  @override
  final primary = const Color(0xFF1D6FE8); // Azul profesional de alto contraste
  @override
  final primaryContainer = const Color(0xFFDBEAFE); // Azul claro 100
  @override
  final onPrimaryContainer = const Color(0xFF1E40AF); // Azul oscuro 900
  @override
  final secondary = const Color(0xFF2563EB); // Azul 600
  @override
  final secondaryContainer = const Color(0xFFEFF6FF); // Azul tenue 50
  @override
  final surface = const Color(0xFFFFFFFF); // Blanco puro
  @override
  final surfaceVariant = const Color(0xFFF1F5F9); // Slate 100 sutil
  @override
  final background = const Color(0xFFF8FAFC); // Canvas Blanco limpio
  @override
  final onSurface = const Color(0xFF0F172A); // Texto carbón nítido
  @override
  final onSurfaceVariant = const Color(0xFF475569); // Texto secundario
  @override
  final outline = const Color(0xFFCBD5E1); // Borde suave
  @override
  final outlineVariant = const Color(0xFFE2E8F0); // Separadores suaves
  @override
  final success = const Color(0xFF10B981); // Emerald 500
  @override
  final warning = const Color(0xFFD97706); // Ámbar 600
  @override
  final error = const Color(0xFFDC2626); // Rojo 600
  @override
  final info = const Color(0xFF0284C7); // Sky 600
  @override
  final tertiary = const Color(0xFF3B82F6); // Blue 500
  @override
  final accent = const Color(0xFF1D6FE8); // Azul Nano principal
  @override
  final onAccent = const Color(0xFFFFFFFF); // Blanco sobre azul
  @override
  final danger = const Color(0xFFDC2626); // Rojo 600
  @override
  final codeBlockBg = const Color(0xFFF1F5F9); // Fondo código suave
  @override
  final quoteBg = const Color(0xFFEFF6FF); // Azul tenue
  @override
  final terminalBg = const Color(0xFFF8FAFC); // Slate 50
  @override
  final terminalGreen = const Color(0xFF1D6FE8); // Azul terminal

  // Tokens de Glassmorphism
  @override
  final glassSurface = const Color(0xEEFFFFFF);
  @override
  final glassBorder = const Color(0x401D6FE8);
  @override
  final glassOverlay = const Color(0x0D1D6FE8);

  // Gradientes metálicos y reflectivos
  @override
  final bgTop = const Color(0xFFFFFFFF);
  @override
  final bgMiddle = const Color(0xFFF8FAF9);
  @override
  final bgBottom = const Color(0xFFEEF5FB);

  @override
  final glass100 = const Color(0xFFEFF7FC);
  @override
  final glass200 = const Color(0xFFFFFFFF);
  @override
  final glass300 = const Color(0xFFDBEAFE);
  @override
  final glass400 = const Color(0xFFF8FAFC);

  @override
  final metalWhite = const Color(0xFFFFFFFF);
  @override
  final metalPearl = const Color(0xFFF8FAFC);
  @override
  final metalSilver = const Color(0xFFDCE5ED);
  @override
  final metalCool = const Color(0xFF94A3B8);
  @override
  final metalSteel = const Color(0xFF64748B);
  @override
  final metalGraphite = const Color(0xFF334155);
  @override
  final metalDark = const Color(0xFF0F172A);

  @override
  final warmReflect1 = const Color(0xFFEFF6FF);
  @override
  final warmReflect2 = const Color(0xFFDBEAFE);
  @override
  final warmReflect3 = const Color(0xFFBFDBFE);

  @override
  final coldReflect1 = const Color(0xFFDBEAFE);
  @override
  final coldReflect2 = const Color(0xFFBFDBFE);
  @override
  final coldReflect3 = const Color(0xFF93C5FD);
  @override
  final coldReflect4 = const Color(0xFF60A5FA);
  @override
  final coldReflect5 = const Color(0xFF1D6FE8);

  @override
  final nanoCyan = const Color(0xFF0284C7);
  @override
  final nanoTurquoise = const Color(0xFF2563EB);
  @override
  final nanoBlue = const Color(0xFF1D6FE8);
  @override
  final nanoViolet = const Color(0xFF1E40AF);

  // Capas de elevación semántica
  @override
  final backgroundPrimary = const Color(0xFFF8FAFC);
  @override
  final backgroundSecondary = const Color(0xFFEFF6FF);
  @override
  final backgroundElevated = const Color(0xFFFFFFFF);
  @override
  final backgroundIce = const Color(0xFFDBEAFE);
  @override
  final backgroundPearl = const Color(0xFFF8FAFC);
  @override
  final backgroundDeep = const Color(0xFFE2E8F0);
  @override
  final backgroundNavy = const Color(0xFFBFDBFE);

  @override
  final glassPrimary = const Color(0xFFFFFFFF);
  @override
  final glassSecondary = const Color(0xFFF8FAFC);
  @override
  final glassGraphite = const Color(0xFFEFF6FF);
  @override
  final glassBlue = const Color(0xFFDBEAFE);

  @override
  final glassLow = 0.15;
  @override
  final glassMedium = 0.30;
  @override
  final glassStrong = 0.45;
  @override
  final glassOpaque = 0.60;

  @override
  final textPrimary = const Color(0xFF0F172A);
  @override
  final textSecondary = const Color(0xFF475569);
  @override
  final textTertiary = const Color(0xFF64748B);
  @override
  final textDisabled = const Color(0xFF94A3B8);

  @override
  final accentCyan = const Color(0xFF0284C7);
  @override
  final accentMint = const Color(0xFF38BDF8);
  @override
  final accentSky = const Color(0xFF60A5FA);
  @override
  final accentBlue = const Color(0xFF1D6FE8);
  @override
  final accentLavender = const Color(0xFF1E40AF);

  @override
  final iceReflection = const Color(0xFFEFF6FF);
  @override
  final silverReflection = const Color(0xFFDBEAFE);
  @override
  final pearlReflection = const Color(0xFFFFFFFF);
  @override
  final warmReflection = const Color(0xFFF0F9FF);
  @override
  final lavenderReflection = const Color(0xFFE0E7FF);

  @override
  final borderPrimaryColor = const Color(0xFFFFFFFF);
  @override
  final borderSecondaryColor = const Color(0xFFE2E8F0);
  @override
  final borderAccentColor = const Color(0x661D6FE8);

  @override
  bool get isClassicOrange => false;
}
