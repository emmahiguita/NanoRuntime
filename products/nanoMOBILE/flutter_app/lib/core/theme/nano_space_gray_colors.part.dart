part of 'design_tokens.dart';

/// Identidad Modo Opaco / Grisáceo: Space Gray / Muted Slate Titanium.
///
/// - QUÉ HACE: Provee una paleta mate de titanio cepillado, grafito y acentos metálicos sutiles.
/// - CÓMO FUNCIONA: Hereda de [NanoDarkColors] y sobrescribe las superficies con tonos pizarra
///   mate (#1C232E), bordes metálicos suaves (#475569) y acentos en azul cielo (#38BDF8).
/// - POR QUÉ: Diseñado para usuarios que prefieren menor contraste visual y texturas mate
///   sin negros puros OLED.
class NanoSpaceGrayColors implements NanoColors {
  const NanoSpaceGrayColors();

  @override
  final primary = const Color(0xFF38BDF8); // Azul cielo metálico
  @override
  final primaryContainer = const Color(0xFF242E3D); // Titanio pizarra oscuro
  @override
  final onPrimaryContainer = const Color(0xFFE2E8F0); // Texto pizarra claro
  @override
  final secondary = const Color(0xFF94A3B8); // Slate 400
  @override
  final secondaryContainer = const Color(0xFF1E2633); // Fondo secundario mate
  @override
  final surface = const Color(0xFF1C232E); // Titanio pizarra mate
  @override
  final surfaceVariant = const Color(0xFF273142); // Superficie elevada cepillada
  @override
  final background = const Color(0xFF13171F); // Grafito mate profundo
  @override
  final onSurface = const Color(0xFFF1F5F9); // Texto blanco-pizarra nítido
  @override
  final onSurfaceVariant = const Color(0xFF94A3B8); // Texto secundario
  @override
  final outline = const Color(0xFF475569); // Borde metálico suave
  @override
  final outlineVariant = const Color(0xFF334155); // Separador pizarra
  @override
  final success = const Color(0xFF10B981); // Emerald 500
  @override
  final warning = const Color(0xFFF59E0B); // Amber 500
  @override
  final error = const Color(0xFFEF4444); // Red 500
  @override
  final info = const Color(0xFF38BDF8); // Sky 400
  @override
  final tertiary = const Color(0xFF64748B); // Slate 500
  @override
  final accent = const Color(0xFF38BDF8); // Azul metálico principal
  @override
  final onAccent = const Color(0xFF0F172A); // Alto contraste sobre acento
  @override
  final danger = const Color(0xFFEF4444);
  @override
  final codeBlockBg = const Color(0xFF181F2A);
  @override
  final quoteBg = const Color(0xFF1E2838);
  @override
  final terminalBg = const Color(0xFF13171F);
  @override
  final terminalGreen = const Color(0xFF34D399);

  // Tokens de Glassmorphism (Titanio mate translúcido)
  @override
  final glassSurface = const Color(0xCC212A38);
  @override
  final glassBorder = const Color(0x3394A3B8);
  @override
  final glassOverlay = const Color(0x0F38BDF8);

  // Gradientes metálicos y reflectivos
  @override
  final bgTop = const Color(0xFF1C232E);
  @override
  final bgMiddle = const Color(0xFF161B24);
  @override
  final bgBottom = const Color(0xFF10141B);

  @override
  final glass100 = const Color(0xFF18202C);
  @override
  final glass200 = const Color(0xFF212A38);
  @override
  final glass300 = const Color(0xFF2A3446);
  @override
  final glass400 = const Color(0xFF334155);

  @override
  final metalWhite = const Color(0xFFF8FAFC);
  @override
  final metalPearl = const Color(0xFFE2E8F0);
  @override
  final metalSilver = const Color(0xFFCBD5E1);
  @override
  final metalCool = const Color(0xFF94A3B8);
  @override
  final metalSteel = const Color(0xFF64748B);
  @override
  final metalGraphite = const Color(0xFF334155);
  @override
  final metalDark = const Color(0xFF1E293B);

  @override
  final warmReflect1 = const Color(0xFF242E3D);
  @override
  final warmReflect2 = const Color(0xFF1E2633);
  @override
  final warmReflect3 = const Color(0xFF18202C);

  @override
  final coldReflect1 = const Color(0xFF242E3D);
  @override
  final coldReflect2 = const Color(0xFF2A3446);
  @override
  final coldReflect3 = const Color(0xFF334155);
  @override
  final coldReflect4 = const Color(0xFF475569);
  @override
  final coldReflect5 = const Color(0xFF38BDF8);

  @override
  final nanoCyan = const Color(0xFF38BDF8);
  @override
  final nanoTurquoise = const Color(0xFF2DD4BF);
  @override
  final nanoBlue = const Color(0xFF60A5FA);
  @override
  final nanoViolet = const Color(0xFF818CF8);

  // Capas de elevación semántica
  @override
  final backgroundPrimary = const Color(0xFF13171F);
  @override
  final backgroundSecondary = const Color(0xFF181E29);
  @override
  final backgroundElevated = const Color(0xFF212A38);
  @override
  final backgroundIce = const Color(0xFF2A3446);
  @override
  final backgroundPearl = const Color(0xFF212A38);
  @override
  final backgroundDeep = const Color(0xFF0E1217);
  @override
  final backgroundNavy = const Color(0xFF182232);

  @override
  final glassPrimary = const Color(0xFF212A38);
  @override
  final glassSecondary = const Color(0xFF1C232E);
  @override
  final glassGraphite = const Color(0xFF273142);
  @override
  final glassBlue = const Color(0xFF1E283A);

  @override
  final glassLow = 0.15;
  @override
  final glassMedium = 0.30;
  @override
  final glassStrong = 0.45;
  @override
  final glassOpaque = 0.60;

  @override
  final textPrimary = const Color(0xFFF1F5F9);
  @override
  final textSecondary = const Color(0xFF94A3B8);
  @override
  final textTertiary = const Color(0xFF64748B);
  @override
  final textDisabled = const Color(0xFF475569);

  @override
  final accentCyan = const Color(0xFF38BDF8);
  @override
  final accentMint = const Color(0xFF2DD4BF);
  @override
  final accentSky = const Color(0xFF60A5FA);
  @override
  final accentBlue = const Color(0xFF38BDF8);
  @override
  final accentLavender = const Color(0xFF818CF8);

  @override
  final iceReflection = const Color(0xFF2A3446);
  @override
  final silverReflection = const Color(0xFF334155);
  @override
  final pearlReflection = const Color(0xFF212A38);
  @override
  final warmReflection = const Color(0xFF1E2633);
  @override
  final lavenderReflection = const Color(0xFF242E3D);

  @override
  final borderPrimaryColor = const Color(0xFF334155);
  @override
  final borderSecondaryColor = const Color(0xFF273142);
  @override
  final borderAccentColor = const Color(0x6638BDF8);

  @override
  bool get isClassicOrange => false;
}
