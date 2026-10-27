part of 'design_tokens.dart';

/// Paleta de sistema en modo claro: Blanco y Azul iOS de alta fidelidad.
///
/// - QUÉ HACE: Extiende [NanoClassicLightColors] adaptando los tokens para coincidir
///   con el tema del sistema operativo.
/// - CÓMO FUNCIONA: Mantiene armonía completa con los esquemas de color nativos del host.
/// - POR QUÉ: Permite que la app herede dinámicamente la configuración del dispositivo.
class NanoSystemLightColors extends NanoClassicLightColors {
  const NanoSystemLightColors();

  @override
  Color get primary => const Color(0xFF1D6FE8); // Azul iOS profesional
  @override
  Color get primaryContainer => const Color(0xFFDBEAFE); // Azul claro 100
  @override
  Color get onPrimaryContainer => const Color(0xFF1E40AF); // Azul profundo 800
  @override
  Color get secondary => const Color(0xFF2563EB); // Azul eléctrico
  @override
  Color get secondaryContainer => const Color(0xFFEFF6FF); // Azul tenue 50
  @override
  Color get surface => const Color(0xFFFFFFFF); // Blanco puro
  @override
  Color get surfaceVariant => const Color(0xFFF1F5F9); // Slate 100 sutil
  @override
  Color get background => const Color(0xFFF8FAFC); // Canvas blanco perlado
  @override
  Color get onSurface => const Color(0xFF0F172A); // Texto carbón nítido
  @override
  Color get onSurfaceVariant => const Color(0xFF475569); // Texto secundario pizarra
  @override
  Color get outline => const Color(0xFFCBD5E1); // Borde suave
  @override
  Color get outlineVariant => const Color(0xFFE2E8F0); // Separador suave
  @override
  Color get accent => const Color(0xFF1D6FE8); // Azul iOS principal
  @override
  Color get onAccent => const Color(0xFFFFFFFF); // Blanco sobre acento
  @override
  Color get glassBorder => const Color(0x331D6FE8); // Borde reflectivo azul
  @override
  Color get glassOverlay => const Color(0x0A1D6FE8); // Aura azul ultra sutil
  @override
  Color get bgTop => const Color(0xFFFFFFFF);
  @override
  Color get bgMiddle => const Color(0xFFF8FAFC);
  @override
  Color get bgBottom => const Color(0xFFEFF6FF);
  @override
  Color get glass100 => const Color(0xFFEFF6FF);
  @override
  Color get glass200 => const Color(0xFFFFFFFF);
  @override
  Color get glass300 => const Color(0xFFDBEAFE);
}

/// Paleta de sistema en modo oscuro: hereda directamente la paleta oscura
/// con superficies profundas y acento azul noble.
class NanoSystemDarkColors extends NanoDarkColors {
  const NanoSystemDarkColors();
}

/// Identidad clásica para modo oscuro con bandera clásica activa.
class NanoClassicDarkColors extends NanoDarkColors {
  const NanoClassicDarkColors();

  @override
  bool get isClassicOrange => true;
}
