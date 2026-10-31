part of 'design_tokens.dart';

/// Modo oscuro negro: fondos neutros, elevación gris carbón y texto claro.
/// Los acentos conservan la identidad Nano; las superficies no se tiñen de azul.
/// Gris espacial mantiene su propia paleta y no hereda estos valores.
class NanoDarkColors implements NanoColors {
  const NanoDarkColors();

  @override
  final primary = const Color(0xFF2563EB); // Azul eléctrico de alto contraste
  @override
  final primaryContainer = const Color(0xFF0C1F3D); // Obsidiana azul profunda
  @override
  final onPrimaryContainer = const Color(0xFFBFDBFE); // Azul claro legible
  @override
  final secondary = const Color(0xFF1D6FE8); // Azul iOS noble
  @override
  final secondaryContainer = const Color(0xFF0F294D); // Deep Blue Container
  @override
  final surface = const Color(0xFF121212); // Superficie negra elevada
  @override
  final surfaceVariant = const Color(0xFF1C1C1E); // Controles sobre negro
  @override
  final background = const Color(0xFF000000); // Fondo negro real
  @override
  final onSurface = const Color(0xFFF8FAFC); // Texto blanco nítido
  @override
  final onSurfaceVariant = const Color(0xFFB9B9BF); // Texto secundario legible
  @override
  final outline = const Color(0xFF606066); // Borde neutro
  @override
  final outlineVariant = const Color(0xFF343438); // Separador neutro
  @override
  final success = const Color(0xFF10B981); // Emerald 500
  @override
  final warning = const Color(0xFFF59E0B); // Amber 500
  @override
  final error = const Color(0xFFEF4444); // Red 500
  @override
  final info = const Color(0xFF38BDF8); // Sky 400
  @override
  final tertiary = const Color(0xFF38BDF8); // Sky 400
  @override
  final accent = const Color(0xFF2563EB); // Azul noble principal
  @override
  final onAccent = const Color(0xFFFFFFFF); // Blanco sobre acento
  @override
  final danger = const Color(0xFFEF4444);
  @override
  final codeBlockBg = const Color(0xFF0D0D0F);
  @override
  final quoteBg = const Color(0xFF19191C);
  @override
  final terminalBg = const Color(0xFF000000);
  @override
  final terminalGreen = const Color(0xFF10B981);

  // Glassmorphism tokens en modo oscuro (superficies mate profundas)
  @override
  final glassSurface = const Color(0xE6121212);
  @override
  final glassBorder = const Color(0x26FFFFFF);
  @override
  final glassOverlay = const Color(0x08000000);

  // Gradientes metálicos y reflectivos
  @override
  final bgTop = const Color(0xFF000000);
  @override
  final bgMiddle = const Color(0xFF030303);
  @override
  final bgBottom = const Color(0xFF060606);

  @override
  final glass100 = const Color(0xFF101010);
  @override
  final glass200 = const Color(0xFF161618);
  @override
  final glass300 = const Color(0xFF1C1C1E);
  @override
  final glass400 = const Color(0xFF242426);

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
  final warmReflect1 = const Color(0xFFEFF6FF);
  @override
  final warmReflect2 = const Color(0xFFDBEAFE);
  @override
  final warmReflect3 = const Color(0xFFBFDBFE);

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
  final nanoCyan = const Color(0xFF38BDF8);
  @override
  final nanoTurquoise = const Color(0xFF60A5FA);
  @override
  final nanoBlue = const Color(0xFF2563EB);
  @override
  final nanoViolet = const Color(0xFF4F46E5);

  // Capas de elevación semántica
  @override
  final backgroundPrimary = const Color(0xFF000000);
  @override
  final backgroundSecondary = const Color(0xFF080808);
  @override
  final backgroundElevated = const Color(0xFF121212);
  @override
  final backgroundDeep = const Color(0xFF000000);
  @override
  final backgroundNavy = const Color(0xFF101012);
  @override
  final backgroundIce = const Color(0xFF161618);
  @override
  final backgroundPearl = const Color(0xFF202022);

  @override
  final glassPrimary = const Color(0xFF101010);
  @override
  final glassSecondary = const Color(0xFF161618);
  @override
  final glassGraphite = const Color(0xFF1C1C1E);
  @override
  final glassBlue = const Color(0xFF18181B);

  @override
  final glassLow = 0.32;
  @override
  final glassMedium = 0.46;
  @override
  final glassStrong = 0.62;
  @override
  final glassOpaque = 0.78;

  @override
  final textPrimary = const Color(0xFFF8FAFC);
  @override
  final textSecondary = const Color(0xFFB9B9BF);
  @override
  final textTertiary = const Color(0xFF98989F);
  @override
  final textDisabled = const Color(0xFF68686D);

  @override
  final accentCyan = const Color(0xFF38BDF8);
  @override
  final accentMint = const Color(0xFF60A5FA);
  @override
  final accentSky = const Color(0xFF93C5FD);
  @override
  final accentBlue = const Color(0xFF2563EB);
  @override
  final accentLavender = const Color(0xFF818CF8);

  @override
  final iceReflection = const Color(0xFFDBEAFE);
  @override
  final silverReflection = const Color(0xFFB9C6D3);
  @override
  final pearlReflection = const Color(0xFFF5F7FA);
  @override
  final warmReflection = const Color(0xFFEFF6FF);
  @override
  final lavenderReflection = const Color(0xFFE0E7FF);

  @override
  final borderPrimaryColor = const Color(0x26FFFFFF);
  @override
  final borderSecondaryColor = const Color(0x2E97A1BF);
  @override
  final borderAccentColor = const Color(0x553B82F6);

  @override
  bool get isClassicOrange => false;
}
