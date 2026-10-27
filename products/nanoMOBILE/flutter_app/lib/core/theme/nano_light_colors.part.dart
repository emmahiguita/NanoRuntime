part of 'design_tokens.dart';

/// Tema Claro: blanco Frost con acentos verdes y texto neutro.
/// Los roles genéricos alimentan controles, ventanas y tarjetas compartidas;
/// los estados de advertencia y error mantienen su significado cromático.
class NanoLightColors implements NanoColors {
  const NanoLightColors();

  @override
  final primary = const Color(0xFF047857); // Verde principal legible sobre blanco
  @override
  final primaryContainer = const Color(0xFFD1FAE5); // Contenedor esmeralda suave
  @override
  final onPrimaryContainer = const Color(0xFF065F46); // Texto sobre el contenedor verde
  @override
  final secondary = const Color(0xFF0F766E); // Verde azulado secundario
  @override
  final secondaryContainer = const Color(0xFFECFDF5); // Contenedor secundario claro
  @override
  final surface = const Color(0xFFFFFFFF); // Blanco puro
  @override
  final surfaceVariant = const Color(0xFFF8FAFC); // Superficie slate neutra
  @override
  final background = const Color(0xFFF8FAFC); // Canvas iOS limpio
  @override
  final onSurface = const Color(0xFF0F172A); // Texto carbón nítido
  @override
  final onSurfaceVariant = const Color(0xFF475569); // Texto secundario
  @override
  final outline = const Color(0xFFCBD5E1); // Borde suave
  @override
  final outlineVariant = const Color(0xFFE2E8F0); // Separadores suaves
  @override
  final success = const Color(0xFF15803D); // Confirmaciones con contraste sobre blanco
  @override
  final warning = const Color(0xFFFF9500); // iOS System Orange
  @override
  final error = const Color(0xFFFF3B30); // iOS System Red
  @override
  final info = const Color(0xFF0F766E); // Información del tema claro
  @override
  final tertiary = const Color(0xFF166534); // Verde oscuro de apoyo
  @override
  final accent = const Color(0xFF047857); // Acento compartido por toda la interfaz
  @override
  final onAccent = const Color(0xFFFFFFFF); // Blanco sobre acento
  @override
  final danger = const Color(0xFFFF3B30); // iOS Red
  @override
  final codeBlockBg = const Color(0xFFF1F5F9); // Fondo código suave
  @override
  final quoteBg = const Color(0xFFF8FAFC); // Slate tenue
  @override
  final terminalBg = const Color(0xFFF8FAFC); // Slate 50
  @override
  final terminalGreen = const Color(0xFF10B981); // Verde terminal

  // Tokens de Glassmorphism (Efecto Cristal Óptico)
  @override
  final glassSurface = const Color(0xEEFFFFFF); // Blanco 93% cristalino
  @override
  final glassBorder = const Color(0x1F000000); // Borde sutil slate translúcido
  @override
  final glassOverlay = const Color(0x05047857); // Reflejo verde de baja intensidad

  // Gradientes metálicos y reflectivos
  @override
  final bgTop = const Color(0xFFFFFFFF);
  @override
  final bgMiddle = const Color(0xFFF8FAFC);
  @override
  final bgBottom = const Color(0xFFF1F5F9);

  @override
  final glass100 = const Color(0xFFF8FAFC);
  @override
  final glass200 = const Color(0xFFFFFFFF);
  @override
  final glass300 = const Color(0xFFF1F5F9);
  @override
  final glass400 = const Color(0xFFE2E8F0);

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
  final warmReflect1 = const Color(0xFFF1F5F9);
  @override
  final warmReflect2 = const Color(0xFFE2E8F0);
  @override
  final warmReflect3 = const Color(0xFFCBD5E1);

  @override
  final coldReflect1 = const Color(0xFFECFDF5); // Reflejo Frost
  @override
  final coldReflect2 = const Color(0xFFD1FAE5); // Reflejo esmeralda suave
  @override
  final coldReflect3 = const Color(0xFFA7F3D0); // Reflejo verde
  @override
  final coldReflect4 = const Color(0xFF6EE7B7); // Reflejo menta
  @override
  final coldReflect5 = const Color(0xFF0F766E); // Reflejo verde oscuro

  @override
  final nanoCyan = const Color(0xFF0F766E); // Alias de acento secundario
  @override
  final nanoTurquoise = const Color(0xFF047857); // Alias de acento principal
  @override
  final nanoBlue = const Color(0xFF047857); // Rol heredado de acento principal
  @override
  final nanoViolet = const Color(0xFF166534); // Rol heredado de acento de apoyo

  // Capas de elevación semántica
  @override
  final backgroundPrimary = const Color(0xFFF8FAFC);
  @override
  final backgroundSecondary = const Color(0xFFF1F5F9);
  @override
  final backgroundElevated = const Color(0xFFFFFFFF);
  @override
  final backgroundIce = const Color(0xFFF1F5F9);
  @override
  final backgroundPearl = const Color(0xFFF8FAFC);
  @override
  final backgroundDeep = const Color(0xFFE2E8F0);
  @override
  final backgroundNavy = const Color(0xFFECFDF5); // Superficie contextual clara

  @override
  final glassPrimary = const Color(0xFFFFFFFF);
  @override
  final glassSecondary = const Color(0xFFF8FAFC);
  @override
  final glassGraphite = const Color(0xFFF1F5F9);
  @override
  final glassBlue = const Color(0xFFECFDF5); // Rol heredado de cristal con tinte suave

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
  final accentCyan = const Color(0xFF0F766E); // Acento secundario
  @override
  final accentMint = const Color(0xFF047857); // Acento verde
  @override
  final accentSky = const Color(0xFF0F766E); // Rol heredado de acento secundario
  @override
  final accentBlue = const Color(0xFF047857); // Rol heredado de acento principal
  @override
  final accentLavender = const Color(0xFF166534); // Rol heredado de acento de apoyo

  @override
  final iceReflection = const Color(0xFFF8FAFC);
  @override
  final silverReflection = const Color(0xFFE2E8F0);
  @override
  final pearlReflection = const Color(0xFFFFFFFF);
  @override
  final warmReflection = const Color(0xFFF8FAFC);
  @override
  final lavenderReflection = const Color(0xFFECFDF5); // Reflejo de superficie claro

  @override
  final borderPrimaryColor = const Color(0xFFE2E8F0);
  @override
  final borderSecondaryColor = const Color(0xFFCBD5E1);
  @override
  final borderAccentColor = const Color(0x33047857); // Borde verde translúcido

  @override
  bool get isClassicOrange => false;
}
